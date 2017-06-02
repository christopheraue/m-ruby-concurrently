# @markup markdown
# @title Basic examples

# Basic examples how to use Concurrently

## Timing Code

### Doing something after X seconds

```
wait X
do_it!
```

### Doing something concurrently after X seconds

```
concurrently do
  wait X
  do_it!
end

# Code here will be executed while the concurrent proc waits.
```

### Doing something concurrently every X seconds

This is a timer.

```
concurrently do
  loop do
    wait X
    do_it!
  end
end
```

### Doing something after X seconds, every Y seconds, Z times

```
concurrently do
  wait X
  Z.times do
    do_it!
    wait Y
  end
end
```

## Handling I/O

```
r,w = IO.pipe

concurrently do
  wait 1
  w.write "Continue!"
end

concurrently do
  # This runs while r awaits readability.
end

concurrently do
  # This runs while r awaits readability.
end

# Read from r. It will take one second until there is input.
message = begin
  r.read_nonblock 1024
rescue IO::WaitReadable
  r.await_readable
  retry
end

puts message # prints "Continue!"

r.close
w.close
```

Writing to IO or other operations like accepting from a ServerSocket work the
same. You just need to use the corresponding `#*_nonblock` methods along with
{IO#await_readable} or {IO#await_writable}.