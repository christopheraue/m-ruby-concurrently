# Basic usage

## Concurrent procs

Concurrently has a single concurrency primitive: the {Concurrently::Proc concurrent proc}.
It looks and feels just like a regular proc. In fact, it inherits from `Proc`.
This means there isn't much you need to learn. Most of the stuff you already
know.

Concurrent procs offer four methods to run them:

* {Concurrently::Proc#call}: Evaluates the concurrent proc and returns the
  result. If it needs to wait for something (like I/O) it blocks the (root
  or concurrent) evaluation it has been called from.
* {Concurrently::Proc#call_nonblock}: Starts evaluating the concurrent proc
  immediately. If it can be evaluated without the need to wait for something
  (like I/O), return its result. If it needs to wait do not block the (root
  or concurrent) evaluation it has been called from and return a
  {Concurrently::Proc::Evaluation proxy for the evaluation} so we can decide
  what to do with it.
* {Concurrently::Proc#call_detached}: Evaluates the concurrent proc in the 
  background the next time there is nothing else to do. It returns a 
  {Concurrently::Proc::Evaluation proxy for the evaluation} so we can control
  it.
* {Concurrently::Proc#call_and_forget}: Evaluate the concurrent proc in the
  background the next time there is nothing else to do and forget about it
  immediately. Its evaluation cannot be controlled any further.

For the curious: Under the cover, each evaluation of a concurrent proc is run
inside a fiber. This let's evaluations be suspended and resumed independently
from each other which is just the basis of concurrency. Concurrent procs are 
mainly a nicer and higher level API built upon those fibers and all the
orchestration needed between them.

## Timing Code

### Doing something after X seconds

```ruby
wait X
do_it!
```

### Doing something concurrently after X seconds

```ruby
concurrently do
  wait X
  do_it!
end

# Code here will be executed while the concurrent proc waits.
```

### Doing something concurrently every X seconds

This is a timer.

```ruby
concurrently do
  loop do
    wait X
    do_it!
  end
end
```

### Doing something after X seconds, every Y seconds, Z times

```ruby
concurrently do
  wait X
  Z.times do
    do_it!
    wait Y
  end
end
```

## Handling I/O

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

Here, `message = r.concurrently_read 1024` is a shortcut for

```ruby
message = begin
  read_nonblock 1024
rescue IO::WaitReadable
  await_readable
  retry
end
```

More about reading and writing concurrently can be found in the documentation
for {IO#concurrently_read} and {IO#concurrently_write}. Other operations like
accepting from a server socket have no `#concurrently_*` method, yet. They need
to be implemented manually by using the corresponding `#*_nonblock` methods
along with {IO#await_readable} or {IO#await_writable} just like in the long form
of `r.concurrently_read 1024`.