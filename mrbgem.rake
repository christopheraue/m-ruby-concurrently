require_relative 'mrblib/version'

MRuby::Gem::Specification.new('mruby-aggregated_timers') do |spec|
  spec.version      = AggregatedTimers::VERSION
  spec.summary      = %q{Manage independent timers or collections of timers and aggregate their collective timeout.}
  spec.description  = <<-DESC
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
DESC
  spec.homepage     = "https://github.com/christopheraue/m-ruby-aggregated_timers"
  spec.license      = 'MIT'
  spec.authors      = ['Christopher Aue']
  spec.email         = ["rubygems@christopheraue.net"]

  spec.add_dependency 'mruby-callbacks_attachable', '~> 1.1', github: 'christopheraue/ruby-callbacks_attachable'
  spec.add_dependency 'mruby-array-ext', :core => 'mruby-array-ext'
end
