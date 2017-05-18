module Concurrently
  class EventWatcher
    class Error < Concurrently::Error; end
    class CancelledError < Error; end
  end
end