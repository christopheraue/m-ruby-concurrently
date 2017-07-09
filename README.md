# Concurrently

[![Build Status](https://secure.travis-ci.org/christopheraue/m-ruby-concurrently.svg?branch=master)](http://travis-ci.org/christopheraue/m-ruby-concurrently)

Concurrently is a concurrency framework for Ruby and mruby built upon
fibers. With it code can be evaluated independently in its own execution
context similar to a thread. Execution contexts are called *evaluations* in
Concurrently and are created with [Kernel#concurrently][]:

```ruby
hello = concurrently do
  wait 0.2 # seconds
  "hello"
end

world = concurrently do
  wait 0.1 # seconds
  "world"
end

puts "#{hello.await_result} #{world.await_result}" 
```

In this example we have three evaluations: The root evaluation and two more
concurrent evaluations started by said root evaluation. The root evaluation
waits until both concurrent evaluations were concluded and then prints "hello
world".


## Synchronization with events

Evaluations can be synchronized with certain events by waiting for them. These
events are:

* an elapsed time period ([Kernel#wait][]),
* readability and writability of IO ([IO#await_readable][],
  [IO#await_writable][]) and
* the result of another evaluation ([Concurrently::Proc::Evaluation#await_result][]).

Since evaluations run independently they are not blocking other evaluations
while waiting.


## Concurrent I/O

When doing I/O it is important to do it **non-blocking**. If the IO object is
not ready use [IO#await_readable][] and [IO#await_writable][] to await
readiness.

For more about non-blocking I/O, see the core ruby docs for
[IO#read_nonblock][] and [IO#write_nonblock][].

This is a little server reading from an IO and printing the received messages:

```ruby
# Let's start with creating a pipe to connect client and server
r,w = IO.pipe

# Server:
# We let the server code run concurrently so it runs independently. It reads
# from the pipe non-blocking and awaits readability if the pipe is not readable.
concurrently do
  while true
    begin
      puts r.read_nonblock 32
    rescue IO::WaitReadable
      r.await_readable
      retry
    end
  end
end

# Client:
# The client writes to the pipe every 0.5 seconds
puts "#{Time.now.strftime('%H:%M:%S.%L')} (Start time)"
while true
  wait 0.5
  w.write Time.now.strftime('%H:%M:%S.%L')
end
```

The root evaluation is effectively blocked by waiting or writing messages.
But since the server runs concurrently it is not affected by this and happily
prints its received messages.

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


[Kernel#concurrently]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrently-instance_method
[Kernel#wait]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#wait-instance_method
[IO#await_readable]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_readable-instance_method
[IO#await_writable]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_writable-instance_method
[Concurrently::Proc::Evaluation#await_result]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#await_result-instance_method
[IO#read_nonblock]: https://ruby-doc.org/core/IO.html#method-i-read_nonblock
[IO#write_nonblock]: https://ruby-doc.org/core/IO.html#method-i-write_nonblock

[installation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Installation.md
[overview]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Overview.md
[documentation]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/index
[troubleshooting]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Troubleshooting.md
[performance]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Performance.md
[release_notes]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/RELEASE_NOTES.md