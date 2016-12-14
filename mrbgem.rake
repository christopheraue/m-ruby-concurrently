require_relative 'mrblib/version'

MRuby::Gem::Specification.new('mruby-io_event_loop') do |spec|
  spec.version      = IOEventLoop::VERSION
  spec.summary      = %q{Comfortably manage IO objects polled by event loop.}
  spec.description  = spec.summary
  spec.homepage     = "https://github.com/christopheraue/m-ruby-io_event_loop"
  spec.license      = 'MIT'
  spec.authors      = ['Christopher Aue']
  spec.email        = ["rubygems@christopheraue.net"]

  spec.add_dependency 'mruby-array-ext', :core => 'mruby-array-ext'
end
