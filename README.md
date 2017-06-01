# Concurrently

Copyright 2015-present Christopher Aue

Licensed under the [Apache License, Version 2.0](LICENSE)

## Summary

Concurrently is a concurrency framework for Ruby and mruby. It serves the same
purpose like [EventMachine](https://github.com/eventmachine/eventmachine) and,
to some extent, [Celluloid](https://github.com/celluloid/celluloid). With it
concurrent code can be written in a linear way similar to async/await.

This API consists of:
* a concurrent proc looking and behaving like a regular proc (+ some secret
  source, of course),
* `#wait` and `#await_*` methods to let concurrent procs await 
  * the end of a time frame,
  * readiness of IO or
  * a result of an evaluation of another concurrent proc and
* an evaluation object for the concurrent procs that acts like a
  future/promise.

A basic example:

```ruby
hello_proc = concurrent_proc do |seconds|
  wait seconds
  puts "Hello World at: #{Time.now.strftime('%H:%M:%S.%L')} (after #{seconds} seconds)"
end

evaluation1 = hello_proc.call_nonblock 1
evaluation2 = hello_proc.call_nonblock 0
evaluation3 = hello_proc.call_nonblock 2
evaluation4 = hello_proc.call_nonblock 0.5

evaluation3.await_result # wait for the longest running evaluation to finish

# Output
# Hello World at: 21:54:19.063 (after 0 seconds)
# Hello World at: 21:54:19.563 (after 0.5 seconds)
# Hello World at: 21:54:20.060 (after 1 seconds)
# Hello World at: 21:54:21.062 (after 2 seconds)
```

That's all! Just a bucket for code, a hand full of methods to wait for stuff
and a placeholder for the result.

## Ruby Installation

Add this line to your application's Gemfile:

```ruby
gem 'concurrently'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install concurrently

## mruby Installation

To directly add it to an mruby build config or GemBox:
```ruby
MRuby::Build.new do |conf| # or MRuby::GemBox.new do |conf|
  conf.gem github: 'christopheraue/m-ruby-concurrently'
end
```

To use it in an mruby gem:
```ruby
MRuby::Gem::Specification.new('mruby-your_gem') do |spec|
  spec.add_dependency 'mruby-concurrently', github: 'christopheraue/m-ruby-concurrently'
end
```

## Usage

TODO

