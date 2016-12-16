require_relative 'mrblib/version'

MRuby::Gem::Specification.new('mruby-io_event_loop') do |spec|
  spec.version      = IOEventLoop::VERSION
  spec.summary      = %q{Comfortably manage IO objects polled by an event loop.}
  spec.description  = spec.summary

  spec.homepage     = "https://github.com/christopheraue/m-ruby-io_event_loop"
  spec.license      = 'MIT'
  spec.authors      = ['Christopher Aue']

  spec.add_dependency 'mruby-fibered_event_loop', '~> 1.0', github: 'christopheraue/m-ruby-fibered_event_loop'
  spec.add_dependency 'mruby-io', github: 'iij/mruby-io'
  spec.add_dependency 'mruby-array-ext', :core => 'mruby-array-ext'
end
