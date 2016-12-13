# coding: utf-8
require_relative 'mrblib/version'

Gem::Specification.new do |spec|
  spec.name          = "io_event_loop"
  spec.version       = IOEventLoop::VERSION
  spec.summary       = %q{Manage independent timers or collections of timers and aggregate their collective timeout.}
  spec.description   = <<-DESC
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

  spec.homepage      = "https://github.com/christopheraue/m-ruby-io_event_loop"
  spec.license       = "MIT"
  spec.authors       = ["Christopher Aue"]
  spec.email         = ["rubygems@christopheraue.net"]

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-mocks-matchers-send_message", "~> 0.3"
end
