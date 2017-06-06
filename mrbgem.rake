require_relative 'mrblib/version'

MRuby::Gem::Specification.new('mruby-concurrently') do |spec|
  spec.version      = Concurrently::VERSION
  spec.summary      = %q{A concurrency framework based on fibers}
  spec.description  = spec.summary

  spec.homepage     = "https://github.com/christopheraue/m-ruby-concurrently"
  spec.license      = 'Apache-2.0'
  spec.authors      = ['Christopher Aue']

  spec.test_rbfiles = Dir.glob("#{File.expand_path File.dirname __FILE__}/mrbtest/tests/*.rb")

  spec.add_dependency 'mruby-fiber', :core => 'mruby-fiber'
  spec.add_dependency 'mruby-io', github: 'iij/mruby-io'
  spec.add_dependency 'mruby-array-ext', :core => 'mruby-array-ext'
  spec.add_dependency 'mruby-callbacks_attachable', '~> 2.0', github: 'christopheraue/m-ruby-callbacks_attachable'
end
