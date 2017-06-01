# coding: utf-8
require_relative 'mrblib/version'

Gem::Specification.new do |spec|
  spec.name         = "concurrently"
  spec.version      = Concurrently::VERSION
  spec.summary      = %q{Comfortably manage IO objects polled by an event loop.}
  spec.description  = spec.summary

  spec.homepage      = "https://github.com/christopheraue/m-ruby-concurrently"
  spec.license       = "Apache-2.0"
  spec.authors       = ["Christopher Aue"]
  spec.email         = ["rubygems@christopheraue.net"]

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "nio4r", "~> 2.0"
  spec.add_runtime_dependency "hitimes", "~> 1.2"
  spec.add_runtime_dependency "callbacks_attachable", "~> 2.0"
  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-mocks-matchers-send_message", "~> 0.3"
end
