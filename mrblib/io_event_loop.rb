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
      next if future.evaluated?
      future.evaluate_to begin
        yield
      rescue Exception => e
        trigger :error, e
        e
      end
      resume
    end

    Future.new(self, @run_queue, fiber)
  end


  # Point of time in the future

  def now_in(seconds)
    TimeFuture.new(self, @run_queue, seconds)
  end


  # Readable IO

  def attach_reader(io, &on_readable)
    @readers[io] = on_readable
  end

  def detach_reader(io)
    @readers.delete(io)
  end

  def readable(io)
    ReadabilityFuture.new self, @run_queue, io
  end


  # Writable IO

  def attach_writer(io, &on_writable)
    @writers[io] = on_writable
  end

  def detach_writer(io)
    @writers.delete(io)
  end

  def writable(io)
    WritabilityFuture.new self, @run_queue, io
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end