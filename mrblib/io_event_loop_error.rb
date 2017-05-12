class IOEventLoop
  class Error < StandardError; end
  class CancelledError < Error; end
  class TimeoutError < CancelledError; end
  class EventWatcherError < Error; end

  class ConcurrentFuture
    Error = IOEventLoop::Error
    CancelledError = IOEventLoop::CancelledError
  end
end
