require "fiber"
require "nio"
require "hitimes"
require "callbacks_attachable"

root = File.dirname File.dirname File.dirname __FILE__
files =
  Dir[File.join(root, 'ext', 'all', '**', '*.rb')].sort +
  Dir[File.join(root, 'ext', 'Ruby', '**', '*.rb')].sort +
  Dir[File.join(root, 'lib', 'all', '**', '*.rb')].sort +
  Dir[File.join(root, 'lib', 'Ruby', '**', '*.rb')].sort
files.each{ |f| require f }
