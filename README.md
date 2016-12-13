# (m)Ruby IOEventLoop

TODO

## Ruby Installation

Add this line to your application's Gemfile:

```ruby
gem 'io_event_loop'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install io_event_loop

## mruby Installation

To directly add it to an mruby build config or GemBox:
```ruby
MRuby::Build.new do |conf| # or MRuby::GemBox.new do |conf|
  conf.gem github: 'christopheraue/m-ruby-io_event_loop'
end
```

To use it in an mruby gem:
```ruby
MRuby::Gem::Specification.new('mruby-your_gem') do |spec|
  spec.add_dependency 'mruby-io_event_loop', github: 'christopheraue/m-ruby-io_event_loop'
end
```

## Usage

TODO

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

