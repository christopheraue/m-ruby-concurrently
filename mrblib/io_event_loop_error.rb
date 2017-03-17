class IOEventLoop < FiberedEventLoop
  class Error < FiberedEventLoop::Error; end
  class TimeoutError < FiberedEventLoop::CancelledError; end
end
