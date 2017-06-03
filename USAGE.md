# Basic examples

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