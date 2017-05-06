Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize(*)
    @wall_clock = WallClock.new

    @run_queue = RunQueue.new self
    @readers = {}
    @writers = {}

    @io_event_loop = Fiber.new do
      while true
        if (waiting_time = @run_queue.waiting_time) == 0
          @run_queue.run_pending
        elsif @readers.any? or @writers.any? or waiting_time
          if selected = IO.select(@readers.keys, @writers.keys, nil, waiting_time)
            selected[0].each{ |readable_io| @readers[readable_io].call } unless selected[0].empty?
            selected[1].each{ |writable_io| @writers[writable_io].call } unless selected[1].empty?
          end
        else
          Fiber.yield # would block indefinitely otherwise
        end
      end
    end
  end

  attr_reader :wall_clock

  def resume
    @io_event_loop.transfer
  end


  # Concurrently executed block of code

  def concurrently # &block
    fiber = Fiber.new do |future|
      future.evaluated? or future.evaluate_to begin
        yield
      rescue Exception => e
        trigger :error, e
        e
      end

      resume
    end

    Future.new(self, @run_queue, fiber)
  end


  # Waiting for a given time

  def wait(seconds)
    @run_queue.schedule_in seconds, Fiber.current
    resume
  end


  # Waiting for a readable IO

  def await_readable(io, opts = {})
    fiber = Fiber.current
    max_seconds = opts[:within]
    timeout = @run_queue.schedule_in max_seconds, fiber, false if max_seconds
    @readers[io] = proc{ @readers.delete(io); fiber.transfer true }
    resume
  ensure
    timeout.cancel if max_seconds
  end


  # Waiting for a writable IO

  def await_writable(io, opts = {})
    fiber = Fiber.current
    max_seconds = opts[:within]
    timeout = @run_queue.schedule_in max_seconds, fiber, false if max_seconds
    @writers[io] = proc{ @writers.delete(io); fiber.transfer true }
    resume
  ensure
    timeout.cancel if max_seconds
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end