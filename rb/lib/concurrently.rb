require "fiber"
require "nio"
require "hitimes"
require "callbacks_attachable"

root = File.dirname File.dirname File.dirname __FILE__
files =
  Dir[File.join(root, 'all', 'ext', '**', '*.rb')].sort +
  Dir[File.join(root,  'rb', 'ext', '**', '*.rb')].sort +
  Dir[File.join(root, 'all', 'lib', '**', '*.rb')].sort +
  Dir[File.join(root,  'rb', 'lib', '**', '*.rb')].sort
files.each{ |f| require f }
