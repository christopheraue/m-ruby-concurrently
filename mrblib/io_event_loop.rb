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
          # forever. But, since we always leave the loop through one of the
          # fibers resumed in the code above, this part of the loop is never
          # reached. When  resuming the loop at a later time it will be because
          # of an added timeout of IO event. So, there will always be something
          # to wait for.
          raise Error, "Infinitely running event loop detected. This " <<
            "should not happen and is considered a bug in this gem."
        end
      end
    end
  end


  # Concurrently executed block of code

  def concurrent_future(future_class = Future, future_data = @empty_future_data) # &block
    fiber = ConcurrentProcFiber.new(self, @run_queue) { yield }
    future = future_class.new(fiber, @event_loop, @run_queue, future_data)
    @run_queue.schedule(fiber, 0, future, :resume)
    future
  end


  # Waiting for a given time

  def wait(seconds)
    fiber = Fiber.current

    @run_queue.schedule(fiber, seconds)
    result = @event_loop.transfer
    @run_queue.cancel fiber

    # If result is a fiber it means this fiber has been evaluated prematurely.
    # In this case transfer back to the given result fiber.
    (Fiber === result) ? result.transfer : :waited
  end


  # Waiting for a readable IO

  def await_readable(io)
    fiber = Fiber.current

    @io_watcher.await_reader(io, fiber)
    result = @event_loop.transfer
    @io_watcher.cancel_reader(io)

    # If result is a fiber it means this fiber has been evaluated prematurely.
    # In this case transfer back to the given result fiber.
    (Fiber === result) ? result.transfer : :readable
  end


  # Waiting for a writable IO

  def await_writable(io)
    fiber = Fiber.current

    @io_watcher.await_writer(io, fiber)
    result = @event_loop.transfer
    @io_watcher.cancel_writer(io)

    # If result is a fiber it means this fiber has been evaluated prematurely.
    # In this case transfer back to the given result fiber.
    (Fiber === result) ? result.transfer : :writable
  end


  # Waiting for an event

  def await_event(subject, event)
    fiber = Fiber.current

    callback = subject.on(event) do |_,result|
      @run_queue.schedule(fiber, 0, result)
    end
    result = @event_loop.transfer
    callback.cancel

    # If result is a fiber it means this fiber has been evaluated prematurely.
    # In this case transfer back to the given result fiber.
    (Fiber === result) ? result.transfer : result
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end