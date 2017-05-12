Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize
    @run_queue = RunQueue.new
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


  # Concurrently executed block of code

  def concurrently(&block)
    fiber = @block_pool.pop || ConcurrentBlock.new(self, @block_pool)
    @run_queue.schedule(fiber, 0)
    fiber.resume(nil, block)
    fiber
  end

  def concurrent_future(klass = ConcurrentFuture, data = @empty_future_data, &block)
    fiber = @block_pool.pop || ConcurrentBlock.new(self, @block_pool)
    @run_queue.schedule(fiber, 0)
    future = klass.new(fiber, self, data)
    fiber.resume(future, block)
    future
  end


  # Awaiting stuff

  def await_outer(opts = {})
    fiber = Fiber.current

    if seconds = opts[:within]
      timeout_result = opts.fetch(:timeout_result, TimeoutError.new("evaluation timed out after #{seconds} second(s)"))
      @run_queue.schedule(fiber, seconds, timeout_result)
    end

    result = yield fiber

    if seconds
      @run_queue.cancel fiber
    end

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely. In this case yield back to the cancelling fiber.
    (result == fiber) ? Fiber.yield : result
  end

  def await_inner(fiber)
    if ConcurrentBlock === fiber
      Fiber.yield # yield back to event loop
    else
      @event_loop.resume # start event loop
    end
  end

  def wait(seconds)
    await_outer do |fiber|
      @run_queue.schedule(fiber, seconds)
      result = await_inner fiber
      @run_queue.cancel fiber
      result
    end
  end

  def await_readable(io)
    await_outer do |fiber|
      @io_watcher.await_reader(io, fiber)
      result = await_inner fiber
      @io_watcher.cancel_reader(io)
      result
    end
  end

  def await_writable(io)
    await_outer do |fiber|
      @io_watcher.await_writer(io, fiber)
      result = await_inner fiber
      @io_watcher.cancel_writer(io)
      result
    end
  end

  def await_event(subject, event)
    await_outer do |fiber|
      callback = subject.on(event) { |_,result| @run_queue.schedule(fiber, 0, result) }
      result = await_inner fiber
      callback.cancel
      result
    end
  end

  def inject_result(fiber, result)
    @run_queue.schedule(fiber, 0, result)
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end