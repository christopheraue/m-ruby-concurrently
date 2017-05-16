class IOEventLoop
  class Error < StandardError; end
  class CancelledError < Error; end
  class TimeoutError < CancelledError; end
  class EventWatcherError < Error; end

  # should not be rescued accidentally and therefore is an exception
  class CancelledConcurrentBlock < Exception; end

  class ConcurrentEvaluation
    Error = IOEventLoop::Error
    CancelledError = IOEventLoop::CancelledError
  end
end
