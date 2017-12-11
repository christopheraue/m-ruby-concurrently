require "bundler/setup"

Bundler.require :test

require "concurrently"

# Load test helpers
Dir["#{File.dirname __FILE__}/_shared/**/*.rb"].sort.each{ |f| require f }

require 'logger'
Concurrently::Debug.enable Logger.new(File.open File::NULL, "w"), ['m-ruby-concurrently/test']
