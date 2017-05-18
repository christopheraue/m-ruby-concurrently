require 'bundler/setup'
Bundler.require(:development)

Dir['./spec/_shared/**/*.rb'].sort.each { |f| require f }

require 'concurrently'

Concurrently::EventLoop.on :loop_iteration_error do |loop, error|
  puts error
  puts error.backtrace
end
