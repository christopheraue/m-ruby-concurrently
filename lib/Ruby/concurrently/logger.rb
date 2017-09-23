module Concurrently
  class Logger
    def self.current
      Thread.current.__concurrently_logger__
    end
  end
end