require 'bundler/setup'
Bundler.require(:development)

Dir['./spec/_shared/**/*.rb'].sort.each { |f| require f }

require 'concurrently'

Concurrently::Proc.on :error do |proc, error|
  puts error
  puts error.backtrace
end
