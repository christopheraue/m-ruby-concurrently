Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize
    @wall_clock = WallClock.new
    @run_queue = RunQueue.new @wall_clock
    @io_watcher = IOWatcher.new
    @block_pool = []

    @empty_future_data = {}.freeze

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

  def concurrently(&block)
    concurrent_block = @block_pool.pop || ConcurrentBlock.new(self, @block_pool, @run_queue)
    concurrent_block.start block
    concurrent_block
  end

  def concurrent_future(klass = ConcurrentFuture, data = @empty_future_data, &block)
    concurrent_block = @block_pool.pop || ConcurrentBlock.new(self, @block_pool, @run_queue)
    future = klass.new(concurrent_block, self, data)
    concurrent_block.start block, future
    future
  end


  # Awaiting stuff

  def await_outer
    fiber = Fiber.current

    result = yield fiber

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely.
    if result == fiber
      @run_queue.cancel fiber # in case the fiber has already been scheduled to resume
      throw :cancel
    else
      result
    end
  end

  def await_inner(fiber, opts = {})
    if seconds = opts[:within]
      timeout_result = opts.fetch(:timeout_result, TimeoutError.new("evaluation timed out after #{seconds} second(s)"))
      @run_queue.schedule(fiber, seconds, timeout_result)
    end

    if ConcurrentBlock::Fiber === fiber
      Fiber.yield # yield back to event loop
    else
      @event_loop.resume # start event loop
    end
  ensure
    if seconds
      @run_queue.cancel fiber
    end
  end

  def wait(seconds)
    fiber = Fiber.current
    @run_queue.schedule(fiber, seconds)

    await_outer do
      await_inner fiber
    end
  ensure
    @run_queue.cancel fiber
  end

  def await_readable(io)
    fiber = Fiber.current
    @io_watcher.await_reader(io, fiber)

    await_outer do
      await_inner fiber
    end
  ensure
    @io_watcher.cancel_reader(io)
  end

  def await_writable(io)
    fiber = Fiber.current
    @io_watcher.await_writer(io, fiber)

    await_outer do
      await_inner fiber
    end
  ensure
    @io_watcher.cancel_writer(io)
  end

  def await_event(subject, event)
    fiber = Fiber.current
    callback = subject.on(event) { |_,result| @run_queue.schedule_now(fiber, result) }

    await_outer do
      await_inner fiber
    end
  ensure
    callback.cancel
  end

  def inject_result(fiber, result)
    @run_queue.schedule_now(fiber, result)
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end