class IOEventLoop
  class Error < StandardError; end
  class CancelledError < Error; end
  class TimeoutError < CancelledError; end
  class EventWatcherError < Error; end
  class CancelledConcurrentBlock < Error; end

  class ConcurrentEvaluation
    Error = IOEventLoop::Error
    CancelledError = IOEventLoop::CancelledError
  end
end
