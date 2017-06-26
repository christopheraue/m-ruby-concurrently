require_relative 'lib/all/concurrently/version'

Gem::Specification.new do |spec|
  spec.name         = "concurrently"
  spec.version      = Concurrently::VERSION
  spec.summary      = %q{A concurrency framework based on fibers}
  spec.description  = <<-DESC
Concurrently is a concurrency framework for Ruby and mruby. With it, concurrent
code can be written sequentially similar to async/await.

The concurrency primitive of Concurrently is the concurrent proc. It is very
similar to a regular proc. Calling a concurrent proc creates a concurrent
evaluation which is kind of a lightweight thread: It can wait for stuff without
blocking other concurrent evaluations.

Under the hood, concurrent procs are evaluated inside fibers. They can wait for
readiness of I/O or a period of time (or the result of other concurrent
evaluations).
  DESC

  spec.homepage      = "https://github.com/christopheraue/m-ruby-concurrently"
  spec.license       = "Apache-2.0"
  spec.authors       = ["Christopher Aue"]
  spec.email         = ["rubygems@christopheraue.net"]
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib/Ruby"]

  spec.required_ruby_version = ">= 2.2.7"

  spec.add_dependency "nio4r", "~> 2.1"
  spec.add_dependency "hitimes", "~> 1.2"
  spec.add_dependency "callbacks_attachable", "~> 2.2"
end
