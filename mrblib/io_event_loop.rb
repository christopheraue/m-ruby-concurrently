Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize(*)
    @run_queue = RunQueue.new
    @io_watcher = IOWatcher.new

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

  def concurrently # &block
    fiber = Fiber.new do |future, return_fiber|
      if future == fiber
        # If future is this very fiber it means this fiber has been evaluated
        # already before its start. Cancel the scheduled start of this fiber
        # and transfer back to the given return_fiber.
        @run_queue.cancel fiber
        return_fiber.transfer
      end

      result = begin
        yield
      rescue Exception => e
        trigger :error, e
        e
      end

      future.evaluate_to result
      @event_loop.transfer
    end

    future = Future.new(fiber, @event_loop, @run_queue)
    @run_queue.schedule(fiber, 0, future)
    future
  end


  # Waiting for a given time

  def wait(seconds)
    fiber = Fiber.current

    @run_queue.schedule(fiber, seconds)
    result, return_fiber = @event_loop.transfer
    @run_queue.cancel fiber

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely. In this case transfer back to the given return_fiber.
    (result == fiber) ? return_fiber.transfer : :waited
  end


  # Waiting for a readable IO

  def await_readable(io)
    fiber = Fiber.current

    @io_watcher.await_reader(fiber, io)
    result, return_fiber = @event_loop.transfer
    @io_watcher.cancel_reader fiber

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely. In this case transfer back to the given return_fiber.
    (result == fiber) ? return_fiber.transfer : :readable
  end


  # Waiting for a writable IO

  def await_writable(io)
    fiber = Fiber.current

    @io_watcher.await_writer(fiber, io)
    result, return_fiber = @event_loop.transfer
    @io_watcher.cancel_writer fiber

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely. In this case transfer back to the given return_fiber.
    (result == fiber) ? return_fiber.transfer : :writable
  end


  # Waiting for an event

  def await_event(subject, event)
    fiber = Fiber.current

    callback = subject.on(event) do |_,result|
      @run_queue.schedule(fiber, 0, result)
    end
    result, return_fiber = @event_loop.transfer
    callback.cancel

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely. In this case transfer back to the given return_fiber.
    (result == fiber) ? return_fiber.transfer : result
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end