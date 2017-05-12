Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize
    @run_queue = RunQueue.new
    @io_watcher = IOWatcher.new

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

  def concurrent_proc(klass = ConcurrentProc, data = @empty_future_data) # &block
    fiber = ConcurrentProcFiber.new(self, @run_queue) { yield }
    concurrent_proc = klass.new(fiber, @event_loop, @run_queue, data)
    @run_queue.schedule(fiber, 0, concurrent_proc)
    concurrent_proc
  end


  # Waiting for a given time

  def wait(seconds)
    fiber = Fiber.current

    @run_queue.schedule(fiber, seconds)
    result = if ConcurrentProcFiber === fiber
      Fiber.yield # yield back to event loop
    else
      @event_loop.resume # start event loop
    end
    @run_queue.cancel fiber

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely. In this case yield back to the cancelling fiber.
    (result == fiber) ? Fiber.yield : :waited
  end


  # Waiting for a readable IO

  def await_readable(io)
    fiber = Fiber.current

    @io_watcher.await_reader(io, fiber)
    result = if ConcurrentProcFiber === fiber
      Fiber.yield # yield back to event loop
    else
      @event_loop.resume # start event loop
    end
    @io_watcher.cancel_reader(io)

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely. In this case yield back to the cancelling fiber.
    (result == fiber) ? Fiber.yield : :readable
  end


  # Waiting for a writable IO

  def await_writable(io)
    fiber = Fiber.current

    @io_watcher.await_writer(io, fiber)
    result = if ConcurrentProcFiber === fiber
      Fiber.yield # yield back to event loop
    else
      @event_loop.resume # start event loop
    end
    @io_watcher.cancel_writer(io)

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely. In this case yield back to the cancelling fiber.
    (result == fiber) ? Fiber.yield : :writable
  end


  # Waiting for an event

  def await_event(subject, event)
    fiber = Fiber.current

    callback = subject.on(event) do |_,result|
      @run_queue.schedule(fiber, 0, result)
    end
    result = if ConcurrentProcFiber === fiber
      Fiber.yield # yield back to event loop
    else
      @event_loop.resume # start event loop
    end
    callback.cancel

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely. In this case yield back to the cancelling fiber.
    (result == fiber) ? Fiber.yield : result
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end