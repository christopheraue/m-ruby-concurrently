class IOEventLoop
  class Error < StandardError; end
  class CancelledError < Error; end
  class TimeoutError < CancelledError; end
  class EventWatcherError < Error; end

  class ConcurrentProc
    Error = IOEventLoop::Error
    TimeoutError = IOEventLoop::TimeoutError
    CancelledError = IOEventLoop::CancelledError
  end
end
