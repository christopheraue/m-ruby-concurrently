# How to Install Concurrently

## Ruby

Install the gem manually with

    $ gem install concurrently

or manage your application's dependencies with [Bundler](https://bundler.io/):
Run

    $ bundle

after you added

    gem 'concurrently'

to your Gemfile.

Finally,

```ruby
require 'concurrently'
```

in your application.


## mruby

To build Concurrently into mruby directly add it to mruby's build config or a
gem box:

```ruby
MRuby::Build.new do |conf| # or MRuby::GemBox.new do |conf|
  conf.gem mgem: 'mruby-concurrently'
end
```

To use it in an mruby gem add it to the gem's specification as dependency:

```ruby
MRuby::Gem::Specification.new('mruby-your-gem') do |spec|
  spec.add_dependency 'mruby-concurrently'
end
```