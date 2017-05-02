class IOEventLoop
  class Error < StandardError; end
  class UnknownWaitingIdError < Error; end
  class CancelledError < Error; end
  class TimeoutError < CancelledError; end
  class EventWatcherError < Error; end
end
