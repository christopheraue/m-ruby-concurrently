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
    fiber = Fiber.new do |future|
      result = begin
        yield
      rescue Exception => e
        trigger :error, e
        e
      end

      future.evaluate_to result
      @event_loop.transfer
    end

    Future.new(fiber, @event_loop, @run_queue, @io_watcher)
  end


  # Waiting for a given time

  def wait(seconds)
    @run_queue.schedule(Fiber.current, seconds)
    @event_loop.transfer
    :waited
  end


  # Waiting for a readable IO

  def await_readable(io)
    fiber = Fiber.current
    @io_watcher.await_reader(fiber, io)
    @event_loop.transfer
    :readable
  ensure
    @io_watcher.cancel fiber
  end


  # Waiting for a writable IO

  def await_writable(io)
    fiber = Fiber.current
    @io_watcher.await_writer(fiber, io)
    @event_loop.transfer
    :writable
  ensure
    @io_watcher.cancel fiber
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end