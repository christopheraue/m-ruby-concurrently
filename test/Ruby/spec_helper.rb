require "bundler/setup"

Bundler.require :test

require "concurrently"

# Load test helpers
Dir["#{File.dirname __FILE__}/_shared/**/*.rb"].sort.each{ |f| require f }

Concurrently::Proc.on :error do |proc, error|
  puts error
  puts error.backtrace
end
