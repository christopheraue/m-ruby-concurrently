# An Overview of Concurrently

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

### Calling Concurrent Procs

A concurrent proc has four methods to call it.

The first two start to evaluate the concurrent proc immediately in the
foreground:

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

### Benchmarking the `#call` Methods

This is a benchmark comparing all `#call` methods of a concurrent proc and a
regular proc in Ruby 2.4.1 on a Intel i7-5820K 3.3 GHz. Both proc types
have an empty block doing nothing:

    proc = proc{}
    conproc = concurrent_proc{}
    
    proc.call:               5843096 iterations executed in 1.0 seconds
    conproc.call:            621627  iterations executed in 1.0 seconds
    conproc.call_nonblock:   716721  iterations executed in 1.0 seconds
    conproc.call_detached:   362884  iterations executed in 1.0012 seconds
    conproc.call_and_forget: 535587  iterations executed in 1.0003 seconds

Explanation of the results:

* The difference between a regular and a concurrent proc is caused by
concurrent procs being evaluated in a fiber.
* Of the two methods evaluating the proc in the foreground, `#call_nonblock`
is faster than `#call`, because `#call` calls `#call_nonblock` and does a
little bit more on top.
* Of the two methods evaluating the proc in the background, `#call_and_forget`
is faster than `#call_detached` because the latter creates an evaluation
object.
* Because the background evaluation of concurrent procs is scheduled and needs
to go through one iteration of the event loop, it is slower than the foreground
evaluation.

You can run the benchmark yourself by running the script [perf/concurrent_proc.rb][].

## Timing Code

To defer the current evaluation use [Kernel#wait][].

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


## Flow of Control

To understand when code is run (and when it is not) it is necessary to know
a little bit more about the way Concurrently works.

Concurrently lets every (real) thread run an [event loop][Concurrently::EventLoop].
These event loops are responsible for watching IOs and scheduling evaluations
of concurrent procs. Evaluations are scheduled by putting them into a run queue
ordered by the time they are supposed to run. The run queue is then worked off
sequentially. If two evaluations are scheduled to run a the same time the
evaluation scheduled first is also run first.

Event loops *do not* run at the exact same time (e.g. on another cpu core)
parallel to your application's code. Instead, your code yields to them if it
waits for something: **The event loop is (and only is) entered if your code
calls `#wait` or one of the `#await_*` methods.** Later, when your code can
be resumed the event loop schedules the corresponding evaluation to run again.

Keep in mind, that an event loop **must never be interrupted, blocked or
overloaded.** A healthy event loop is one that can respond to new events
immediately.

If you are experiencing issues when using Concurrently it is probably due to
these properties of event loops. Have a look at the [Troubleshooting][] page. 


## Bootstrapping an Application

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
[Kernel#concurrent_proc]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrent_proc-instance_method
[Kernel#concurrently]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrently-instance_method
[Kernel#wait]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#wait-instance_method
[IO#await_readable]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_readable-instance_method
[IO#await_writable]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_writable-instance_method
[IO#concurrently_read]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#concurrently_read-instance_method
[IO#concurrently_write]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#concurrently_write-instance_method
[Troubleshooting]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/guides/Troubleshooting.md
[perf/concurrent_proc.rb]: https://github.com/christopheraue/m-ruby-concurrently/blob/master/perf/concurrent_proc.rb