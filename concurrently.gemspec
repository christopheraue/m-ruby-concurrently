# coding: utf-8
require_relative 'mrblib/version'

Gem::Specification.new do |spec|
  spec.name         = "concurrently"
  spec.version      = Concurrently::VERSION
  spec.summary      = %q{A concurrency framework based on fibers}
  spec.description  = spec.summary

  spec.homepage      = "https://github.com/christopheraue/m-ruby-concurrently"
  spec.license       = "Apache-2.0"
  spec.authors       = ["Christopher Aue"]
  spec.email         = ["rubygems@christopheraue.net"]
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.2.7"

  spec.add_dependency "nio4r", "~> 2.1"
  spec.add_dependency "hitimes", "~> 1.2"
  spec.add_dependency "callbacks_attachable", "~> 2.2"
end
