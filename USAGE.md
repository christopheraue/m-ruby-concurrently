# An overview of Concurrently

This document is meant as a general overview of what can be done with
Concurrently and how it works. For more information and examples about a topic
follow the interspersed links to the documentation.

## Evaluations

An evaluation is an atomic thread of execution leading to a result. It is
similar to a thread or a fiber. It can be suspended and resumed independently
from other evaluations. It is also similar to a future or a promise by
providing access to its future result or offering the ability to conclude it
prematurely.

Every ruby program already has an implicit {Concurrently::Evaluation root
evaluation} running. Calling a concurrent proc creates a
{Concurrently::Proc::Evaluation proc evaluation}.


## Concurrent Procs

The {Concurrently::Proc concurrent proc} is Concurrently's concurrency
primitive. It looks and feels just like a regular proc. In fact,
{Concurrently::Proc} inherits from `Proc`.

Concurrent procs are created with {Kernel#concurrent_proc}:

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

* {Concurrently::Proc#call} blocks the (root or proc) evaluation it has
  been called from until its evaluation is concluded. Then it returns the
  result. This behaves just like `Proc#call`.
* {Concurrently::Proc#call_nonblock} won't block the (root or proc)
  evaluation it has been called from if it needs to wait for something. In such
  a case, it does not wait until its evaluated and instead returns its
  {Concurrently::Proc::Evaluation evaluation}.

The other two schedule the concurrent proc to run in the background. It won't
run right away and will be started during the next iteration of the event loop:

* {Concurrently::Proc#call_detached} returns an {Concurrently::Proc::Evaluation
  evaluation}.
* {Concurrently::Proc#call_and_forget} forgets about the evaluation immediately
  and returns `nil`.

There is a shortcut for {Concurrently::Proc#call_and_forget}:

```ruby
concurrently do
  # code to run concurrently
end
```

is the same as

```ruby
concurrent_proc do
  # code to run concurrently
end.call_and_forget
```


## Timing Code

To defer the current evaluation use {Kernel#wait}.

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

Readiness of I/O is awaited with {IO#await_readable} and {IO#await_writable}. To
read and write from an IO you can use {IO#concurrently_read} and
{IO#concurrently_write}.

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
the corresponding `#*_nonblock` methods along with {IO#await_readable} or
{IO#await_writable}:

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


## Flow of control

To explain when code is run (and when it is not) it is necessary to understand
a little bit more about the way Concurrently works.

Concurrently lets every thread run an {Concurrently::EventLoop event loop}.
These event loops are responsible for watching IOs and scheduling evaluations
of concurrent procs. They *do not* run at the exact same time (e.g. on another
cpu core) parallel to your application's code. Instead, your code yields to the
event loop if it waits for something with `#wait` or one of the `#await_*`
methods. And the event loop yields back to a waiting evaluation in your code
when it can be resumed.

So, the general rule of thumb is: **The event loop is (and only is) entered if
your code calls `#wait` or one of the `#await_*` methods.**


## Bootstrapping an application

The easiest way to start using Concurrently in your application is to wrap its
code in a concurrent proc and call it:

```ruby
#! /bin/env ruby

main = concurrent_proc do
  # spin up your application here
end

main.call
```

This main evaluation will exit as soon as there are no more concurrent proc to
be started and there is nothing more to wait for.