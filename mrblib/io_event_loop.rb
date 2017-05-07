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
          @run_queue.process_pending
        elsif @readers.any? or @writers.any? or waiting_time
          if selected = IO.select(@readers.keys, @writers.keys, nil, waiting_time)
            selected[0].each{ |readable_io| @readers[readable_io].transfer true } unless selected[0].empty?
            selected[1].each{ |writable_io| @writers[writable_io].transfer true } unless selected[1].empty?
          end
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

  attr_reader :wall_clock

  def resume
    @io_event_loop.transfer
  end


  # Concurrently executed block of code

  def concurrently # &block
    fiber = Fiber.new do |future|
      if future.evaluated?
        # Evaluated/cancelled before the fiber has been scheduled to run.
        resume
      else
        result = begin
          yield
        rescue Exception => e
          trigger :error, e
          e
        end

        if future.evaluated?
          # Evaluated/cancelled while waited in the concurrent block.
          resume
        else
          future.evaluate_to result
          resume
        end
      end
    end

    Future.new(self, @run_queue, fiber)
  end


  # Waiting for a given time

  def wait(seconds)
    @run_queue.schedule Fiber.current, seconds
    resume
  end


  # Waiting for a readable IO

  def await_readable(io, opts = {})
    fiber = Fiber.current
    max_seconds = opts[:within]
    @run_queue.schedule fiber, max_seconds, false if max_seconds
    @readers[io] = fiber
    resume
  ensure
    @readers.delete io
    @run_queue.cancel fiber if max_seconds
  end


  # Waiting for a writable IO

  def await_writable(io, opts = {})
    fiber = Fiber.current
    max_seconds = opts[:within]
    @run_queue.schedule fiber, max_seconds, false if max_seconds
    @writers[io] = fiber
    resume
  ensure
    @writers.delete io
    @run_queue.cancel fiber if max_seconds
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end