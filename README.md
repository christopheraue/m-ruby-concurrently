# (m)Ruby AggregatedTimers

Manage independent one-time or recurring timers. Timers can be put into a
collection to get aggregated values of all timers. Collections of timers
can also be organized in groups (i.e. in another collection layer). Aggregation
across collections of timer collections works identical to aggregation across
collection of timers.

Example scenario: A couple of actors are attached to a single event loop.
Each request an actor sends gets its own timer that times out if waiting for
a response takes too long. Each actor collects the timers of its requests in a
collection. When attaching the actor to the event loop its timer collection
is put into the timer collection of the event loop.

Thus, the event loop manages a collection of each attached actor's timer
collection. When the event loop polls for new input it limits the waiting time
to the shortest timer interval across all its actors.

## Ruby Installation

Add this line to your application's Gemfile:

```ruby
gem 'aggregated_timers'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install aggregated_timers

## mruby Installation

To directly add it to an mruby build config or GemBox:
```ruby
MRuby::Build.new do |conf| # or MRuby::GemBox.new do |conf|
  conf.gem github: 'christopheraue/m-ruby-aggregated_timers'
end
```

To use it in an mruby gem:
```ruby
MRuby::Gem::Specification.new('mruby-your_gem') do |spec|
  spec.add_dependency 'mruby-aggregated_timers', github: 'christopheraue/m-ruby-aggregated_timers'
end
```

## Usage

TODO

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

