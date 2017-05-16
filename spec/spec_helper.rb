require 'bundler/setup'
Bundler.require(:development)

Dir['./spec/_shared/**/*.rb'].sort.each { |f| require f }

require 'io_event_loop'
