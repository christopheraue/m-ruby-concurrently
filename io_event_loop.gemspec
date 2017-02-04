# coding: utf-8
load './mrblib/version.rb'

Gem::Specification.new do |spec|
  spec.name         = "io_event_loop"
  spec.version      = IOEventLoop::VERSION
  spec.summary      = %q{Comfortably manage IO objects polled by an event loop.}
  spec.description  = spec.summary

  spec.homepage      = "https://github.com/christopheraue/m-ruby-io_event_loop"
  spec.license       = "MIT"
  spec.authors       = ["Christopher Aue"]
  spec.email         = ["rubygems@christopheraue.net"]

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "fibered_event_loop", "~> 1.6"
  spec.add_runtime_dependency "hitimes", "~> 1.2"
  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-mocks-matchers-send_message", "~> 0.3"
end
