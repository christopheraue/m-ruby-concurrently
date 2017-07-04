# Concurrently

[![Build Status](https://secure.travis-ci.org/christopheraue/m-ruby-concurrently.svg?branch=master)](http://travis-ci.org/christopheraue/m-ruby-concurrently)

Concurrently is a concurrency framework for Ruby and mruby. With it, concurrent
code can be written sequentially similar to async/await.

The concurrency primitive of Concurrently is the concurrent proc. It is very
similar to a regular proc. Calling a concurrent proc creates a concurrent
evaluation which is kind of a lightweight thread: It can wait for stuff without
blocking other concurrent evaluations.

Under the hood, concurrent procs are evaluated inside fibers. They can wait for
readiness of I/O or a period of time (or the result of other concurrent
evaluations). The interface is comparable to plain Ruby:

<table>
  <tr>
    <th>Plain Ruby</th>
    <th>Concurrently</th>
  </tr>
  <tr>
    <td><code>Fiber.new(&block).resume</code></td>
    <td><code>concurrent_proc(&block).call</code></td>
  </tr>
  <tr>
    <td><code>IO.select([io])</code></td>
    <td><code>io.await_readable</code></td>
  </tr>
  <tr>
    <td><code>IO.select(nil, [io])</code></td>
    <td><code>io.await_writable</code></td>
  </tr>
  <tr>
    <td><code>IO.select(nil, nil, nil, seconds)</code></td>
    <td><code>wait(seconds)</code></td>
  </tr>
</table>

Beyond the mere beautification of the interface, Concurrently also takes care
of the management of the event loop and the coordination between all concurrent
evaluations.


## A Basic Example

This is a little server reading from an IO and printing the received messages:

```ruby
server = concurrent_proc do |io|
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

Now, we create a pipe and start the server with the read end of it:

```ruby
r,w = IO.pipe
server.call_detached r
```

Finally, we write messages to the write end of the pipe every 0.5 seconds:

```ruby
puts "#{Time.now.strftime('%H:%M:%S.%L')} (Start time)"

while true
  wait 0.5
  w.write Time.now.strftime('%H:%M:%S.%L')
end
```

The evaluation of the root fiber is effectively blocked by waiting or writing
messages. But since the server runs concurrently it is not affected by this and
happily prints its received messages.

This is the output:

```
23:20:42.357 (Start time)
23:20:42.858
23:20:43.359
23:20:43.860
23:20:44.360
...
```


## Documentation

* [Installation][installation]
* [An Overview of Concurrently][overview]
* [API documentation][documentation]
* [Troubleshooting][troubleshooting]
* [Performance][performance]


## Supported Ruby Versions

* Ruby 2.2.7+
* mruby 1.3+


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
[performance]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Performance.md
[release_notes]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/RELEASE_NOTES.md