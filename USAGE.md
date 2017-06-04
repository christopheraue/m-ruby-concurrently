# An overview of Concurrently

This document is meant as a general overview of what can be done with
Concurrently and how all its parts work together. For more information and
examples about a topic follow the interspersed links to the documentation.

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

* {Concurrently::Proc#call} blocks the (root or proc) evaluation it has been
  called from until its own evaluation is concluded. Then it returns the
  result. This behaves just like `Proc#call`.
* {Concurrently::Proc#call_nonblock} will not block the (root or proc)
  evaluation it has been called from if it waits for something. Instead, it
  immediately returns its {Concurrently::Proc::Evaluation evaluation}. If it
  can be evaluated without waiting it returns the result.

The other two schedule the concurrent proc to run in the background. The
evaluation is not started right away but is deferred until the the next
iteration of the event loop:

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

This can lead to the following effects:

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

`concurrently{}` is a shortcut for `concurrent_proc{}.call_and_forget`.
{Concurrently::Proc#call_and_forget} does not evaluate its code right away but
schedules it to run during the next iteration of the event loop. But, since the
root evaluation did not await anything the event loop has never been entered
and the evaluation of the concurrent proc has never been started.

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

This approach is not perfect. It is not very efficient if we would not need to
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