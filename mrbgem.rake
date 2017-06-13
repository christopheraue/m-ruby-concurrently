require_relative 'all/lib/concurrently/version'

MRuby::Gem::Specification.new('mruby-concurrently') do |spec|
  spec.version      = Concurrently::VERSION
  spec.summary      = %q{A concurrency framework based on fibers}
  spec.description  = spec.summary

  spec.homepage     = "https://github.com/christopheraue/m-ruby-concurrently"
  spec.license      = 'Apache-2.0'
  spec.authors      = ['Christopher Aue']

  # patch build process so we can set source files with spec.rbfiles
  @generate_functions = true
  @objs << objfile("#{build_dir}/gem_init")

  spec.rbfiles      =
    Dir["#{spec.dir}/all/ext/**/*.rb"].sort +
    Dir["#{spec.dir}/mrb/ext/**/*.rb"].sort +
    Dir["#{spec.dir}/all/lib/**/*.rb"].sort +
    Dir["#{spec.dir}/mrb/lib/**/*.rb"].sort
  spec.test_rbfiles = Dir["#{spec.dir}/mrb/test/*.rb"]

  spec.add_dependency 'mruby-array-ext', :core => 'mruby-array-ext'
  spec.add_dependency 'mruby-numeric-ext', :core => 'mruby-numeric-ext'
  spec.add_dependency 'mruby-enumerator', :core => 'mruby-enumerator'
  spec.add_dependency 'mruby-fiber', :core => 'mruby-fiber'
  spec.add_dependency 'mruby-time', :core => 'mruby-time'
  spec.add_dependency 'mruby-io', github: 'christopheraue/mruby-io'
  spec.add_dependency 'mruby-callbacks_attachable', '~> 2.0', github: 'christopheraue/m-ruby-callbacks_attachable'
end
