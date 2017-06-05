# Concurrently

Concurrently is a concurrency framework based on fibers for Ruby and mruby.

It serves the same purpose like [EventMachine](https://github.com/eventmachine/eventmachine)
and, to some extent, [Celluloid](https://github.com/celluloid/celluloid).

To run code concurrently, it is defined as a concurrent proc. These concurrent
procs are very similar to regular procs, except when they are called their code
is evaluated in a fiber (that is a lightweight thread). This lets their
evaluation be suspended and resumed independent from the evaluations of other
concurrent procs. Along with methods to wait for a time period, await readiness
of I/O and await the result of other evaluations, concurrent code can be
written linearly similar to async/await.

## A very basic example

Let's write a little server reading from an IO and printing the received
messages:

```ruby
def start_receiving_messages_from(io)
  while true
    begin
      puts io.read_nonblock 32
    rescue IO::WaitReadable
      io.await_readable
      retry
    end
  end
end
```

This is a client sending a timestamp every 0.5 seconds:

```ruby
def start_sending_messages_to(io)
  while true
    wait 0.5
    io.write Time.now.strftime('%H:%M:%S.%L')
  end
end
```

And now, we connect both through a pipe:

```ruby
r,w = IO.pipe

concurrently do
  start_sending_messages_to w
end

puts "#{Time.now.strftime('%H:%M:%S.%L')} (Start time)"
start_receiving_messages_from r
```

The evaluation of the root thread is effectively blocked by our server
listening to the read end of the pipe. But since the client runs concurrently
it is not affected by this and happily sends outs its messages.

This is the output:

```
23:20:42.357 (Start time)
23:20:42.858
23:20:43.359
23:20:43.860
23:20:44.360
...
```


## Installation & Documentation

* [Installation instructions][installation]
* [An Introduction to Concurrently][introduction]
* [API documentation][documentation]


## Development

[Release Notes][release_notes]


## License

Copyright 2016-present Christopher Aue

Concurrently is licensed under the Apache License, Version 2.0. Please see the
file called LICENSE.


[installation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/Installation.md
[introduction]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/Introduction.md
[documentation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/index
[release_notes]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/ReleaseNotes.md