# Concurrently

Concurrently is a concurrency framework based on fibers for Ruby and mruby.

It serves the same purpose like [EventMachine](https://github.com/eventmachine/eventmachine)
and, to some extent, [Celluloid](https://github.com/celluloid/celluloid).

To run code concurrently, it is defined as a concurrent proc. These concurrent
procs are very similar to regular procs, except when they are called their code
is evaluated in a fiber (which is kind of a lightweight thread). This lets their
evaluation be suspended and resumed independently from evaluations of other
concurrent procs. Along with methods to wait for a time period, await readiness
of I/O and await the result of other evaluations, concurrent code can be
written linearly similar to async/await.

## A very basic example

Let's write a little server reading from an IO and printing the received
messages:

```ruby
printer = concurrent_proc do |io|
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

And now, we call it detached from the root fiber and send out messages every
0.5 seconds.

```ruby
r,w = IO.pipe

printer.call_detached r

puts "#{Time.now.strftime('%H:%M:%S.%L')} (Start time)"

while true
  wait 0.5
  w.write Time.now.strftime('%H:%M:%S.%L')
end
```

The evaluation of the root fiber is effectively blocked by waiting or sending
messages through the pipe. But since the server runs concurrently it is not
affected by this and happily prints its received messages.

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
* [An Overview of Concurrently][overview]
* [API documentation][documentation]
* [Troubleshooting][troubleshooting]


## Supported Ruby Versions

* Ruby 2.2.7+, 2.3, 2.4
* mruby 1.3


## Development

[Release Notes][release_notes]


## License

Copyright 2016-present Christopher Aue

Concurrently is licensed under the Apache License, Version 2.0. Please see the
file called LICENSE.


[installation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Installation.md
[overview]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Overview.md
[documentation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/index
[troubleshooting]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Troubleshooting.md
[release_notes]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/RELEASE_NOTES.md