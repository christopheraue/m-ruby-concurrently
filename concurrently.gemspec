require_relative 'lib/all/concurrently/version'

Gem::Specification.new do |spec|
  spec.name         = "concurrently"
  spec.version      = Concurrently::VERSION
  spec.summary      = %q{A concurrency framework based on fibers}
  spec.description  = <<'DESC'
Concurrently is a concurrency framework for Ruby and mruby based on
fibers. With it code can be evaluated independently in its own execution
context similar to a thread:

    hello = concurrently do
      wait 0.2 # seconds
      "hello"
    end
    
    world = concurrently do
      wait 0.1 # seconds
      "world"
    end
    
    puts "#{hello.await_result} #{world.await_result}"
DESC

  spec.homepage      = "https://github.com/christopheraue/m-ruby-concurrently"
  spec.license       = "Apache-2.0"
  spec.authors       = ["Christopher Aue"]
  spec.email         = ["rubygems@christopheraue.net"]
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib/CRuby"]

  spec.required_ruby_version = ">= 2.2.7"

  spec.add_dependency "nio4r", "~> 2.1"
  spec.add_dependency "hitimes", "~> 1.2"
  spec.add_dependency "callbacks_attachable", "~> 3.0"
end
