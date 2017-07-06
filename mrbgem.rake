require_relative 'lib/all/concurrently/version'

MRuby::Gem::Specification.new('mruby-concurrently') do |spec|
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

  spec.homepage     = "https://github.com/christopheraue/m-ruby-concurrently"
  spec.license      = 'Apache-2.0'
  spec.authors      = ['Christopher Aue']

  # patch build process so we can set source files with spec.rbfiles
  @generate_functions = true
  @objs << objfile("#{build_dir}/gem_init")

  spec.rbfiles      =
    Dir["#{spec.dir}/ext/all/**/*.rb"].sort +
    Dir["#{spec.dir}/ext/mruby/**/*.rb"].sort +
    Dir["#{spec.dir}/lib/all/**/*.rb"].sort +
    Dir["#{spec.dir}/lib/mruby/**/*.rb"].sort
  spec.test_rbfiles = Dir["#{spec.dir}/test/mruby/*.rb"]

  spec.add_dependency 'mruby-array-ext', :core => 'mruby-array-ext'
  spec.add_dependency 'mruby-numeric-ext', :core => 'mruby-numeric-ext'
  spec.add_dependency 'mruby-enumerator', :core => 'mruby-enumerator'
  spec.add_dependency 'mruby-fiber', :core => 'mruby-fiber'
  spec.add_dependency 'mruby-time', :core => 'mruby-time'
  spec.add_dependency 'mruby-io'
  spec.add_dependency 'mruby-callbacks_attachable', '~> 2.2', github: 'christopheraue/m-ruby-callbacks_attachable'

  # Deactivate mruby-poll until https://github.com/Asmod4n/mruby-poll/issues/2
  # is fixed.
  # use mruby-poll only on unix-like OSes
  #if ENV['VisualStudioVersion'] || ENV['VSINSTALLDIR']
    spec.rbfiles.delete "#{spec.dir}/lib/mruby/concurrently/event_loop/io_selector.rb"
  # else
  #   spec.add_dependency 'mruby-poll'
  # end
end
