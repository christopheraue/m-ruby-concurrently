require_relative 'mrblib/version'

MRuby::Gem::Specification.new('mruby-concurrently') do |spec|
  spec.version      = Concurrently::VERSION
  spec.summary      = %q{Comfortably manage IO objects polled by an event loop.}
  spec.description  = spec.summary

  spec.homepage     = "https://github.com/christopheraue/m-ruby-concurrently"
  spec.license      = 'MIT'
  spec.authors      = ['Christopher Aue']

  spec.add_dependency 'mruby-fiber', :core => 'mruby-fiber'
  spec.add_dependency 'mruby-io', github: 'iij/mruby-io'
  spec.add_dependency 'mruby-array-ext', :core => 'mruby-array-ext'
  spec.add_dependency 'mruby-callbacks_attachable', '~> 2.0', github: 'christopheraue/m-ruby-callbacks_attachable'
end
