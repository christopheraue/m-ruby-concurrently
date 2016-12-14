require "fibered_event_loop"

dir = File.dirname File.dirname __FILE__
Dir[File.join(dir, 'mrblib', '*.rb')].sort.each{ |f| require f }