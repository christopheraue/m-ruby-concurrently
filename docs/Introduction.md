# An Introduction to Concurrently

This document is meant as a general overview of what can be done with
Concurrently and how all its parts work together. For more information and
examples about a topic follow the interspersed links to the documentation.

## Evaluations

An evaluation is an atomic thread of execution leading to a result. It is
similar to a thread or a fiber. It can be suspended and resumed independently
from other evaluations. It is also similar to a future or a promise by
providing access to its future result or offering the ability to conclude it
prematurely.

Every ruby program already has an implicit [root evaluation][Concurrently::Evaluation]
running. Calling a concurrent proc creates a [proc evaluation][Concurrently::Proc::Evaluation].

## Concurrent Procs

The [concurrent proc][Concurrently::Proc] is Concurrently's concurrency
primitive. It looks and feels just like a regular proc. In fact,
[Concurrently::Proc][] inherits from `Proc`.

Concurrent procs are created with [Kernel#concurrent_proc][]:

```ruby
concurrent_proc do
  # code to run concurrently
end
```

Concurrent procs can be used the same way regular procs are used. For example,
they can be passed around or called multiple times with different arguments.

### Calling concurrent procs

A concurrent proc has four methods to call it.

The first two start to evaluate the concurrent proc immediately:

* [Concurrently::Proc#call][] blocks the (root or proc) evaluation it has been
  called from until its own evaluation is concluded. Then it returns the
  result. This behaves just like `Proc#call`.
* [Concurrently::Proc#call_nonblock][] will not block the (root or proc)
  evaluation it has been called from if it waits for something. Instead, it
  immediately returns its [evaluation][Concurrently::Proc::Evaluation]. If it
  can be evaluated without waiting it returns the result.

The other two schedule the concurrent proc to run in the background. The
evaluation is not started right away but is deferred until the the next
iteration of the event loop:

* [Concurrently::Proc#call_detached][] returns an [evaluation][Concurrently::Proc::Evaluation].
* [Concurrently::Proc#call_and_forget][] forgets about the evaluation immediately
    and returns `nil`.
    
    [Kernel#concurrently] is a shortcut for [Concurrently::Proc#call_and_forget][]:
    
    ```ruby
    concurrently do
      # code to run concurrently
    end
    
    # is equivalent to:
    
    concurrent_proc do
      # code to run concurrently
    end.call_and_forget
    ```


## Timing Code

To defer the current evaluation use [Kernel#wait][].

### Doing something after X seconds

```ruby
concurrent_proc do
  wait X
  do_it!
end
```

### Doing something every X seconds

This is a timer.

```ruby
concurrent_proc do
  loop do
    wait X
    do_it!
  end
end
```

### Doing something after X seconds, every Y seconds, Z times

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
To read and write from an IO you can use [IO#concurrently_read][] and
[IO#concurrently_write][].

```ruby
r,w = IO.pipe

concurrently do
  wait 1
  w.concurrently_write "Continue!"
end

concurrently do
  # This runs while r awaits readability.
end

concurrently do
  # This runs while r awaits readability.
end

# Read from r. It will take one second until there is input.
message = r.concurrently_read 1024

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


## Flow of control and Troubleshooting

To explain when code is run (and when it is not) it is necessary to understand
a little bit more about the way Concurrently works.

Concurrently lets every thread run an [event loop][Concurrently::EventLoop].
These event loops are responsible for watching IOs and scheduling evaluations
of concurrent procs. They **must never be interrupted, blocked or overloaded.**
A healthy event loop is one that can respond to new events immediately.

Event loops *do not* run at the exact same time (e.g. on another cpu core)
parallel to your application's code. Instead, your code yields to them if it
waits for something. **An event loop is (and only is) entered if your code
calls `#wait` or one of the `#await_*` methods.** Later, when your code can
be resumed the event loop yields back to it.

These properties of event loops can lead to the following effects:

### A concurrent proc is scheduled but never run

Consider the following script:

```ruby
#!/bin/env ruby

concurrently do
  puts "I will be forgotten, like tears in the rain."
end

puts "Unicorns!"
```

Running it will only print:

```
Unicorns!
```

[Kernel#concurrently][] is a shortcut for [Concurrently::Proc#call_and_forget][]
which in turn does not evaluate its code right away but schedules it to run
during the next iteration of the event loop. But, since the root evaluation did
not await anything the event loop has never been entered and the evaluation of
the concurrent proc has never been started.

A more subtle variation of this behavior occurs in the following scenario:

```ruby
#!/bin/env ruby

concurrently do
  puts "Unicorns!"
  wait 2
  puts "I will be forgotten, like tears in the rain."
end

wait 1
```

Running it will also only print:

```
Unicorns!
```

This time, the root evaluation does await something, namely the end of a one
second time frame. Because of this, the evaluation of the `concurrently` block
is indeed started and immediately waits for two seconds. After one second the
root evaluation is resumed and exits. The `concurrently` block is never awoken
again from its now eternal beauty sleep.

### A call is blocking the entire execution.

```ruby
#!/bin/env ruby

r,w = IO.pipe

concurrently do
  w.write 'Wake up!'
end

r.readpartial 32
```

Here, although we are practically waiting for `r` to be readable we do so in a
blocking manner (`IO#readpartial` is blocking). This brings the whole process
to a halt, the event loop will not be entered and the `concurrently` block will
not be run. It will not be written to the pipe which in turn creates a nice
deadlock.

You can use blocking calls to deal with I/O. But you should await readiness of
the IO before. If instead of just `r.readpartial 32` we write:

```ruby
r.await_readable
r.readpartial 32
```

we suspend the root evaluation, switch to the event loop which runs the
`concurrently` block and once there is something to read from `r` the root
evaluation is resumed.

This approach is not perfect. It is not very efficient if we do not need to
await readability at all and could read from `r` immediately. But it is still
better than blocking everything by default.

The most efficient way is doing a non-blocking read and only await readability
if it is not readable:

```ruby
begin
  r.read_nonblock 32
rescue IO::WaitReadable
  r.await_readable
  retry
end
```

### The event loop is jammed by too many or too expensive evaluations

Let's talk about a concurrent proc with an infinite loop:

```ruby
evaluation = concurrent_proc do
  loop do
    puts "To infinity! And beyond!"
  end
end.call_detached

concurrently do
  evaluation.conclude_to :cancelled
end
```

When the concurrent proc is scheduled to run it runs and runs and runs and
never finishes. The event loop is never entered again and the other concurrent
proc concluding the evaluation is never started.

A less extreme example is something like:

```ruby
concurrent_proc do
  loop do
    wait 0.1
    puts "timer triggered at: #{Time.now.strftime('%H:%M:%S.%L')}"
    concurrently do
      sleep 1 # defers the entire event loop
    end
  end
end.call

# => timer triggered at: 16:08:17.704
# => timer triggered at: 16:08:18.705
# => timer triggered at: 16:08:19.705
# => timer triggered at: 16:08:20.705
# => timer triggered at: 16:08:21.706
```

This is a timer that is supposed to run every 0.1 seconds and creates another
evaluation that takes a full second to complete. But since it takes so long the
loop also only gets a chance to run every second leading to a delay of 0.9
seconds between the time the timer is supposed to run and the time it actually
ran.

### Errors tear down the event loop
  
Every concurrent proc rescues the following errors happening during its
evaluation: `NoMemoryError`, `ScriptError`, `SecurityError`, `StandardError`
and `SystemStackError`. These are all errors that should not have an immediate
influence on other evaluations or the application as a whole. They will not
leak to the event loop and will not tear it down.

All other errors happening inside a concurrent proc *will* tear down the
event loop. These error types are: `SignalException`, `SystemExit` and the
general `Exception`. In such a case the event loop exits by raising a
[Concurrently::Error][].

If your application rescues the error when the event loop is teared down
and continues running you get a couple of fiber errors (probably "dead
fiber called").


## Bootstrapping an application

Considering a server application with a single server socket accepting
connections, how can such an application be built?

Here is a simplified (i.e. imperfect) example to show the general idea:

```ruby
#!/bin/env ruby

require 'socket'

accept_connection = concurrent_proc do |socket|
  until socket.closed?
    message = socket.concurrently_read 4096
    request = extract_request_from message
    response = request.evaluate
    socket.concurrently_write response
  end
end

start_server = concurrent_proc do |server|
  until server.closed?
    begin
      # Handle each socket concurrently so it can await readiness without
      # blocking the server.
      accept_connection.call_detached server.accept_nonblock
    rescue IO::WaitReadable
      server.await_readable
      retry
    end
  end
end

server = UNIXServer.new "/tmp/sock"
start_server.call server # blocks as long as the server loop is running
```

[Concurrently::Evaluation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation
[Concurrently::Proc]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc
[Concurrently::Proc#call]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call-instance_method
[Concurrently::Proc#call_nonblock]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_nonblock-instance_method
[Concurrently::Proc#call_detached]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_detached-instance_method
[Concurrently::Proc#call_and_forget]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_and_forget-instance_method
[Concurrently::Proc::Evaluation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation
[Concurrently::EventLoop]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop
[Concurrently::Error]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Error
[Kernel#concurrent_proc]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrent_proc-instance_method
[Kernel#concurrently]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrently-instance_method
[Kernel#wait]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#wait-instance_method
[IO#await_readable]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_readable-instance_method
[IO#await_writable]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_writable-instance_method
[IO#concurrently_read]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#concurrently_read-instance_method
[IO#concurrently_write]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#concurrently_write-instance_method