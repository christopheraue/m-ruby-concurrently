require "fiber"
require "nio"
require "hitimes"
require "callbacks_attachable"

dir = File.dirname File.dirname __FILE__
Dir[File.join(dir, 'mrblib', '*.rb')].reject{ |f| f.end_with? '_m.rb' }.sort.each{ |f| require f }
Dir[File.join(dir, 'lib', '*.rb')].sort.each{ |f| require f }