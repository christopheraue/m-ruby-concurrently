class IOEventLoop
  class Error < StandardError; end
  class CancelledError < Error; end
  class TimeoutError < CancelledError; end
  class EventWatcherError < Error; end

  # should not be rescued accidentally and therefore is an exception
  class ProcFiberCancelled < Exception; end
end
