require 'bundler'

# Set up and load Concurrently
Bundler.setup(:default)
require 'concurrently'

# Set up an load test dependencies
Bundler.setup(:test)
Bundler.require(:test)

# Load test helpers
Dir['./spec/_shared/**/*.rb'].sort.each { |f| require f }

Concurrently::Proc.on :error do |proc, error|
  puts error
  puts error.backtrace
end
