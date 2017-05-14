Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize
    @wall_clock = WallClock.new
    @run_queue = RunQueue.new @wall_clock
    @io_watcher = IOWatcher.new
    @block_pool = []

    @empty_call_stack = [].freeze

    @event_loop = Fiber.new do
      while true
        waiting_time = @run_queue.waiting_time

        if waiting_time == 0
          @run_queue.process_pending
        elsif @io_watcher.awaiting? or waiting_time
          @io_watcher.process_ready_in waiting_time
        else
          # Having no pending timeouts or IO events would make run this loop
          # forever. But, since we always start the loop from one of the
          # *await* methods, it is also always returning to them after waiting
          # is complete. Therefore, we never reach this part of the code unless
          # there is a bug or it is messed around with the internals of this gem.
          raise Error, "Infinitely running event loop detected. There either "\
            "is a bug in the io_event_loop gem or you messed around with the "\
            "internals of said gem."
        end
      end
    end
  end

  def lifetime
    @wall_clock.now
  end


  # Concurrently executed block of code
  def fresh_concurrent_block
    @block_pool.pop || ConcurrentBlock.new(self, @block_pool)
  end

  def concurrently # &block
    concurrent_block = @block_pool.pop || ConcurrentBlock.new(self, @block_pool)
    # ConcurrentProc.new claims the method's block just like Proc.new does
    @run_queue.schedule_now concurrent_block, ConcurrentProc.new(self)
    concurrent_block
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

    result = if ConcurrentBlock === fiber
      Fiber.yield # yield back to event loop
    else
      @event_loop.resume # start event loop
    end

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

  def await_readable(io)
    fiber = Fiber.current
    @io_watcher.await_reader(io, fiber)
    await_manual_resume!
  ensure
    @io_watcher.cancel_reader(io)
  end

  def await_writable(io)
    fiber = Fiber.current
    @io_watcher.await_writer(io, fiber)
    await_manual_resume!
  ensure
    @io_watcher.cancel_writer(io)
  end

  def await_event(subject, event)
    fiber = Fiber.current
    callback = subject.on(event) { |_,result| @run_queue.schedule_now(fiber, result) }
    await_manual_resume!
  ensure
    callback.cancel
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end