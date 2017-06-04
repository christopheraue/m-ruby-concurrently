# Basic usage

## Concurrent Procs

Concurrently has a single concurrency primitive: the {Concurrently::Proc concurrent proc}.
It looks and feels just like a regular proc. In fact, it inherits from `Proc`.
This means there isn't much to get used to.

Concurrent procs are created with {Kernel#concurrent_proc}:

```ruby
concurrent_proc do
  # code to run concurrently
end
```

You can use concurrent procs the same way you use regular procs. They can be
passed around, called multiple times with different arguments and so on.

### Running them

A concurrent proc has four methods to run it.

The first two run the concurrent proc immediately:

* {Concurrently::Proc#call}: Blocks the (root or concurrent) evaluation it has
  been called from. Just like a normal proc does. But if it needs to wait for
  something (like I/O) it won't block any other concurrent evaluations.
* {Concurrently::Proc#call_nonblock}: Won't block the (root or concurrent)
  evaluation it has been called from if it needs to wait for something (like
  I/O). In that case, it returns right away with a
  {Concurrently::Proc::Evaluation proxy for the evaluation} to control it.

The other two schedule the concurrent proc to run in the background. It won't
run right away and will be started during the next iteration of the event loop:

* {Concurrently::Proc#call_detached}: Returns a {Concurrently::Proc::Evaluation
  proxy for the evaluation} to control it.
* {Concurrently::Proc#call_and_forget}: Forgets about the evaluation. It cannot be
  controlled any further.

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

### For the curious

Under the cover, each evaluation of a concurrent proc is run
inside a fiber. This let's evaluations be suspended and resumed independently
from each other which is the basis of concurrency. Concurrent procs are 
mainly a nicer and higher level API built upon those fibers and all the
orchestration needed between them.


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