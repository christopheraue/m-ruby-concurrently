# An Overview of Concurrently

The [README][] already introduced the basic interface of Concurrently. 
This document explores the underlying concepts and explains how all parts work
together. For even more details and examples about a specific topic follow the
interspersed links to the [API documentation][].

Let's start with the concept of an *evaluation*.


## Evaluations

An evaluation is an independent execution context. It is similar to a thread or
a fiber since it can be suspended and resumed independently from other
evaluations.

Every ruby program already has an implicit [root evaluation][Concurrently::Evaluation]
running. Unless you explicitly tell your program to evaluate code concurrently
it is evaluated in the root evaluation. The root evaluation runs as long as
your program is running. Thus it is never concluded and its result cannot be
awaited.

Evaluating code with `concurrently(&block)` is done in its own type of
[evaluation][Concurrently::Proc::Evaluation]. Contrary to the root evaluation,
this evaluation has an end with a result. Next to its similarity to a thread
resp. fiber it is also similar to a future or a promise. It provides access
to its (future) result and offers the ability to shortcut its execution by
manually injecting a result. Once the evaluation has a result it is *concluded*.

```ruby
# This is the root evaluation

concurrently do
  # This is a concurrent evaluation
end

concurrently do
  # This is another concurrent evaluation
end
```

## Concurrent Evaluation of Code

Evaluating a piece of code concurrently involves three distinct phases:

                   1)     2)     3)
    evaluation0 ---+-------------+--->
                   |             |
    evaluation1    `-------------´

1) Invocation: evaluation0 creates a separate execution context evaluation1 to
   evaluate the code in. It does not wait for evaluation1 to finish.
2) Asynchronicity: evaluation0 and evaluation1 run independently from each
   other. evaluation0 does not know whether evaluation1 has finished or not.
3) Synchronization: If evaluation0 needs the result of evaluation1 it has to
   wait for it. This synchronizes evaluation1 with evaluation0 again. If
   evaluation1 has not finished yet evaluation0 blocks until it has.

Every tool Concurrently offers is linked to one of these phases.


### Invocation

To start evaluating code concurrently use [Kernel#concurrently][]:

```ruby
evaluation = concurrently do
  # code to run concurrently
end
```

It returns immediately with a handle to the started evaluation. The evaluation
will be processed in the background.

[Kernel#concurrently][] is actually a shortcut for

```ruby
evaluation = concurrent_proc do
  # code to run concurrently
end.call_detached
```

In general, you do not need to work with concurrent procs directly. Just use
[Kernel#concurrently][]. But concurrent procs give you a finer control over
how the code is evaluated. This comes in handy for optimizing performance.


#### Concurrent Procs

The [concurrent proc][Concurrently::Proc] looks and feels just like a regular
proc. In fact, [Concurrently::Proc][] inherits from `Proc`. It is created with
[Kernel#concurrent_proc][]:

```ruby
conproc = concurrent_proc do
  # code to run concurrently
end
```

Concurrent procs can be used the same way regular procs are. For example, they
can be passed around or called multiple times with different arguments.

When called a concurrent proc kicks of an evaluation of its code. A concurrent
proc has four methods to call it. Depending on which method is used the code
is evaluated slightly differently.

The first two methods evaluate the concurrent proc immediately in the
foreground:

* [Concurrently::Proc#call][] blocks the evaluation it has been called from
  until its own evaluation is concluded. Then it returns the result. This
  behaves just like `Proc#call`.
* [Concurrently::Proc#call_nonblock][] will not block the evaluation it has
  been called from if it needs to wait. Instead, it immediately returns its 
  own [evaluation][Concurrently::Proc::Evaluation]. If it can be evaluated
  without waiting it returns the result.

The other two schedule the concurrent proc to be run in the background. The
evaluation is not started right away but is deferred until the the next
iteration of the event loop:

* [Concurrently::Proc#call_detached][] returns an [evaluation][Concurrently::Proc::Evaluation].
* [Concurrently::Proc#call_and_forget][] does not give access to the evaluation
    and returns `nil`.

The different methods to call a concurrent proc have an impact on the execution
speed. In general, [Concurrently::Proc#call_detached][] represents a good
middle ground between ease of use and performance. For an in-depth analysis of
the performance implications of each call method have a look at the
[performance documentation][performance]. It offers a guide what to use if
every cpu cycle counts.

## Timing Code

To defer the current evaluation for a fixed time use [Kernel#wait][].

* Doing something after X seconds:
    
    ```ruby
    concurrent_proc do
      wait X
      do_it!
    end
    ```

* Doing something every X seconds. This is a timer:
    
    ```ruby
    concurrent_proc do
      loop do
        wait X
        do_it!
      end
    end
    ```

* Doing something after X seconds, every Y seconds, Z times:
    
    ```ruby
    concurrent_proc do
      wait X
      Z.times do
        do_it!
        wait Y
      end
    end
    ```


## Handling I/O

Readiness of I/O is awaited with [IO#await_readable][] and [IO#await_writable][].
To read and write from an IO and wait until the operation is complete without
blocking other evaluations you can use [IO#await_read][] and [IO#await_written][].

```ruby
r,w = IO.pipe

concurrently do
  wait 1
  w.await_written "Continue!"
end

concurrently do
  # This runs while r awaits readability.
end

concurrently do
  # This runs while r awaits readability.
end

# Read from r. It will take one second until there is input.
message = r.await_read 1024

puts message # prints "Continue!"

r.close
w.close
```

Other operations like accepting from a server socket need to be done by using
the corresponding `#*_nonblock` methods along with [IO#await_readable][] or
[IO#await_writable][]:

```ruby
require 'socket'

server = UNIXServer.new "/tmp/sock"

begin
  socket = server.accept_nonblock
rescue IO::WaitReadable
  server.await_readable
  retry
end

# socket is an accepted socket.
```


## Flow of Control

To understand when code is run (and when it is not) it is necessary to know
a little bit more about the way Concurrently works.

Concurrently lets every (real) thread run an [event loop][Concurrently::EventLoop].
These event loops are responsible for watching IOs and scheduling evaluations
of concurrent procs. Evaluations are scheduled by putting them into a run queue
ordered by the time they are supposed to run. The run queue is then worked off
sequentially. If two evaluations are scheduled to run at the same time the
evaluation scheduled first is run first.

Event loops *do not* run parallel to your application's code at the exact same
time (e.g. on another cpu core). Instead, your code yields to them if it
waits for something: **The event loop is (and only is) entered if your code
calls `#wait` or one of the `#await_*` methods.** Later, when your code can
be resumed the event loop schedules the corresponding evaluation to run again.

Keep in mind, that an event loop **must never be interrupted, blocked or
overloaded.** A healthy event loop is one that can respond to new events
immediately.

If you are experiencing issues when using Concurrently it is probably due to
these properties of event loops. Have a look at the [Troubleshooting][] page. 


## Implementing a Server Application

This is a blueprint how to build an application listening to a server socket,
accepting connections and serving requests through them.

At first, lets implement the server. It is initialized with a socket to listen
to. Listening calls the concurrent proc stored in the `RECEIVER` constant. It
then accepts or waits for incoming connections until the server is closed.

```ruby
class ConcurrentServer
  def initialize(socket)
    @socket = socket
    @listening = false
  end
  
  def listening?
    @listening
  end
  
  def listen
    @listening = true
    RECEIVER.call_nonblock self, @socket
  end
  
  def close
    @listening = false
    @socket.close
  end
  
  RECEIVER = concurrent_proc do |server, socket|
    while server.listening?
      begin
        Connection.new(socket.accept_nonblock).open
      rescue IO::WaitReadable
        socket.await_readable
        retry
      end
    end
  end
end
```

The implementation of the connection is structurally similar to the one of the
server. But because receiving data is a little bit more complex it is done in
an additional receive buffer object. Received requests are processed in their
own concurrent proc to not block the receiver loop if `request.process` calls
one of the wait methods.

```ruby
class ConcurrentServer::Connection
  def initialize(socket)
    @socket = socket
    @receive_buffer = ReceiveBuffer.new socket
    @open = false
  end
  
  def open?
    @open
  end
  
  def open
    @open = true
    RECEIVER.call_nonblock self, @receive_buffer
  end
  
  def close
    @open = false
    @socket.close
  end
  
  RECEIVER = concurrent_proc do |connection, receive_buffer|
    while connection.open?
      receive_buffer.receive
      receive_buffer.shift_complete_requests.each do |request|
        REQUEST_PROC.call_nonblock request
      end
    end
  end
  
  REQUEST_PROC = concurrent_proc do |request|
    request.process
  end
end
```

The receive buffer is responsible for reading from the connection's socket and
deserializing the received data.

```ruby
class ConcurrentServer::Connection::ReceiveBuffer
  def initialize(socket)
    @socket = socket
    @buffer = ''
  end

  def receive
    @buffer << @socket.read_nonblock(32768)
  rescue IO::WaitReadable
    @socket.await_readable
    retry
  end
  
  def shift_complete_requests
    # Deserializes the buffer according to the used wire protocol, removes
    # the consumed bytes of all completely received requests from the buffer
    # and returns the requests.
  end
end
```

Finally, this is a script bootstrapping two concurrent servers. The script
terminates after both servers were closed.

```ruby
#!/bin/env ruby

require 'socket'

socket1 = UNIXServer.new "/tmp/sock1"
socket2 = UNIXServer.new "/tmp/sock2"

server_evaluation1 = ConcurrentServer.new(socket1).listen
server_evaluation2 = ConcurrentServer.new(socket2).listen

server_evaluation1.await_result # blocks until server 1 is closed
server_evaluation2.await_result # returns immediately if server 2 is already
                                # closed or blocks until it happens
```

Keep in mind, that to focus on the use of Concurrently the example does not
take error handling for I/O, properly closing all connections and other details
into account.

[README]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/README.md
[API documentation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/index
[performance]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Performance.md
[Concurrently::Evaluation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation
[Concurrently::Proc]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc
[Concurrently::Proc#call]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call-instance_method
[Concurrently::Proc#call_nonblock]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_nonblock-instance_method
[Concurrently::Proc#call_detached]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_detached-instance_method
[Concurrently::Proc#call_and_forget]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_and_forget-instance_method
[Concurrently::Proc::Evaluation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation
[Concurrently::EventLoop]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop
[Kernel#concurrent_proc]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrent_proc-instance_method
[Kernel#concurrently]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrently-instance_method
[Kernel#wait]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#wait-instance_method
[IO#await_readable]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_readable-instance_method
[IO#await_writable]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_writable-instance_method
[IO#await_read]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_read-instance_method
[IO#await_written]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_written-instance_method
[Troubleshooting]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Troubleshooting.md