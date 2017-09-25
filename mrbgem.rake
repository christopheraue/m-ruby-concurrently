require_relative 'lib/all/concurrently/version'

MRuby::Gem::Specification.new('mruby-concurrently') do |spec|
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

  spec.homepage     = "https://github.com/christopheraue/m-ruby-concurrently"
  spec.license      = 'Apache-2.0'
  spec.authors      = ['Christopher Aue']

  unless system("git merge-base --is-ancestor 5a9eedf5417266b82e3695ae0c29797182a5d04e HEAD")
    # mruby commit 5a9eedf fixed the usage of spec.rbfiles. mruby 1.3.0
    # did not have that commit, yet. Add the patch for this case:
    @generate_functions = true
    @objs << objfile("#{build_dir}/gem_init")
  end

  spec.rbfiles      =
    Dir["#{spec.dir}/ext/all/**/*.rb"].sort +
    Dir["#{spec.dir}/ext/mruby/**/*.rb"].sort +
    Dir["#{spec.dir}/lib/all/**/*.rb"].sort +
    Dir["#{spec.dir}/lib/mruby/**/*.rb"].sort
  spec.test_rbfiles = Dir["#{spec.dir}/test/mruby/*.rb"]

  spec.add_dependency 'mruby-array-ext', :core => 'mruby-array-ext'
  spec.add_dependency 'mruby-numeric-ext', :core => 'mruby-numeric-ext'
  spec.add_dependency 'mruby-proc-ext', :core => 'mruby-proc-ext'
  spec.add_dependency 'mruby-kernel-ext', :core => 'mruby-kernel-ext'
  spec.add_dependency 'mruby-enumerator', :core => 'mruby-enumerator'
  spec.add_dependency 'mruby-fiber', :core => 'mruby-fiber'
  spec.add_dependency 'mruby-time', :core => 'mruby-time'
  spec.add_dependency 'mruby-io'
  spec.add_dependency 'mruby-callbacks_attachable', '~> 2.2', github: 'christopheraue/m-ruby-callbacks_attachable'

  # use mruby-poll only on unix-like OSes
  if ENV['VisualStudioVersion'] || ENV['VSINSTALLDIR']
    spec.rbfiles.delete "#{spec.dir}/lib/mruby/concurrently/event_loop/io_selector.rb"
  else
    spec.add_dependency 'mruby-poll'
  end
end
