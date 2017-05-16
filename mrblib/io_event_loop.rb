Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize
    @wall_clock = WallClock.new
    @run_queue = RunQueue.new @wall_clock
    @io_watcher = IOWatcher.new
    @event_loop = EventLoop.new(@run_queue, @io_watcher)

    @block_pool = []
    @empty_call_stack = [].freeze
  end

  def lifetime
    @wall_clock.now
  end


  # Concurrently executed block of code
  def concurrent_block!
    @block_pool.pop || ConcurrentBlock.new(self, @block_pool)
  end

  def concurrently # &block
    # ConcurrentProc.new claims the method's block just like Proc.new does
    ConcurrentProc.new(self).call_detached!
  end

  def concurrent_proc(evaluation_class = ConcurrentEvaluation) # &block
    # ConcurrentProc.new claims the method's block just like Proc.new does
    ConcurrentProc.new(self, evaluation_class)
  end


  # Awaiting stuff

  def await_manual_resume!(opts = {})
    fiber = Fiber.current

    if seconds = opts[:within]
      timeout_result = opts.fetch(:timeout_result, TimeoutError.new("evaluation timed out after #{seconds} second(s)"))
      @run_queue.schedule(fiber, seconds, timeout_result)
    end

    result = fiber.send_to_background! @event_loop

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely.
    if result == fiber
      @run_queue.cancel fiber # in case the fiber has already been scheduled to resume
      raise CancelledConcurrentBlock, '', @empty_call_stack
    else
      result
    end
  ensure
    if seconds
      @run_queue.cancel fiber
    end
  end

  def manually_resume!(fiber, result = nil)
    @run_queue.schedule_now(fiber, result)
  end

  def wait(seconds)
    fiber = Fiber.current
    @run_queue.schedule(fiber, seconds)
    await_manual_resume!
  ensure
    @run_queue.cancel fiber
  end

  def await_readable(io, opts = {})
    fiber = Fiber.current
    @io_watcher.await_reader(io, fiber)
    await_manual_resume! opts
  ensure
    @io_watcher.cancel_reader(io)
  end

  def await_writable(io, opts = {})
    fiber = Fiber.current
    @io_watcher.await_writer(io, fiber)
    await_manual_resume! opts
  ensure
    @io_watcher.cancel_writer(io)
  end

  def await_event(subject, event, opts = {})
    fiber = Fiber.current
    callback = subject.on(event) { |_,result| @run_queue.schedule_now(fiber, result) }
    await_manual_resume! opts
  ensure
    callback.cancel
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end