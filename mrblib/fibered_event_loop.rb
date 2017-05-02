class FiberedEventLoop
  include CallbacksAttachable

  def initialize(&iteration)
    @iteration = iteration
    @running = false
    @waiting = {}
    @once = []
    @stop_and_raise_error = on(:error) { |_,e| stop IOEventLoop::CancelledError.new(e) }
  end

  def forgive_iteration_errors!
    @stop_and_raise_error.cancel
  end

  def start
    @running = true

    while @running
      if @once.any?
        while fiber = @once.pop
          fiber.resume
        end
      else
        begin
          @iteration.call
        rescue Exception => e
          trigger :error, e
        end
      end
    end

    (IOEventLoop::CancelledError === @result) ? raise(@result) : @result
  end

  def stop(result = nil)
    @running = false
    @result = result
  end

  def running?
    @running
  end

  def once(&block)
    @once.unshift IOEventLoop::RescuedFiber.new(self, &block)
  end

  def await(id)
    case @waiting[id] = ::Fiber.current
    when IOEventLoop::Fiber
      result = ::Fiber.yield
      (IOEventLoop::CancelledError === result) ? raise(result) : result
    else
      start
    end
  end

  def awaits?(id)
    @waiting.key? id
  end

  def resume(id, result)
    case fiber = @waiting.delete(id)
    when nil
      raise IOEventLoop::UnknownWaitingIdError, "unknown waiting id #{id.inspect}"
    when IOEventLoop::Fiber
      fiber.resume result
    else
      stop result
    end
  end

  def cancel(id, reason = "waiting for id #{id.inspect} cancelled")
    resume id, IOEventLoop::CancelledError.new(reason)
    :cancelled
  end

  def watch_events(*args)
    IOEventLoop::EventWatcher.new(self, *args)
  end
end