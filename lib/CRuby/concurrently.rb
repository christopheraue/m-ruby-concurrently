require "fiber"
require "nio"
require "hitimes"
require "callbacks_attachable"

root = File.dirname File.dirname File.dirname __FILE__
files =
  Dir[File.join(root, 'ext', 'all', '**', '*.rb')].sort +
  Dir[File.join(root, 'ext', 'CRuby', '**', '*.rb')].sort +
  Dir[File.join(root, 'lib', 'all', '**', '*.rb')].sort +
  Dir[File.join(root, 'lib', 'CRuby', '**', '*.rb')].sort
files.each{ |f| require f }
