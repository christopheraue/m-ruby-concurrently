Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize(*)
    @wall_clock = WallClock.new

    @running = false
    @stop_and_raise_error = on(:error) { |_,e| stop CancelledError.new(e) }

    @concurrencies = {}
    @waiting_concurrencies = {}

    @run_queue = RunQueue.new self
    @readers = {}
    @writers = {}
  end

  def forgive_iteration_errors!
    @stop_and_raise_error.cancel
  end

  attr_reader :wall_clock


  # Flow control

  attr_reader :concurrencies, :waiting_concurrencies

  def start
    @running = true

    while @running
      if (waiting_time = @run_queue.waiting_time) == 0
        @run_queue.run_pending
      elsif @readers.any? or @writers.any? or waiting_time
        if selected = IO.select(@readers.keys, @writers.keys, nil, waiting_time)
          selected[0].each{ |readable_io| @readers[readable_io].call } unless selected[0].empty?
          selected[1].each{ |writable_io| @writers[writable_io].call } unless selected[1].empty?
        end
      else
        @running = false # would block indefinitely otherwise
      end
    end

    (CancelledError === @result) ? raise(@result) : @result
  end

  def stop(result = nil)
    @running = false
    @result = result
  end

  def running?
    @running
  end

  def once(&block)
    concurrency = Concurrency.new(self, @run_queue, &block)
    concurrency.schedule_at @wall_clock.now
  end

  def await(id, opts = {})
    if concurrency = @concurrencies[Fiber.current]
      @waiting_concurrencies[id] = concurrency
      concurrency.wait_id = id
      concurrency.await_result opts
    else
      raise Error, "cannot await on root fiber"
    end
  end

  def resume(id, result)
    if concurrency = @waiting_concurrencies.delete(id)
      concurrency.resume_with result
    else
      raise UnknownWaitingIdError, "unknown waiting id #{id.inspect}"
    end
  end

  def awaits?(id)
    @waiting_concurrencies.key? id
  end

  def cancel(id, reason = "waiting for id #{id.inspect} cancelled")
    resume id, CancelledError.new(reason)
    :cancelled
  end


  # Timers

  def after(seconds, &on_timeout)
    concurrency = Concurrency.new(self, @run_queue, &on_timeout)
    concurrency.schedule_at @wall_clock.now+seconds
    concurrency
  end

  def every(seconds) # &on_timeout
    concurrency = after(seconds) do
      while true
        concurrency.schedule_at concurrency.schedule_time+seconds
        yield
        concurrency.await_result
      end
    end
  end


  # Readable IO

  def attach_reader(io, &on_readable)
    @readers[io] = on_readable
  end

  def detach_reader(io)
    @readers.delete(io)
  end

  def await_readable(io, *args, &block)
    attach_reader(io) { detach_reader(io); resume(io, :readable) }
    await io, *args, &block
  end

  def awaits_readable?(io)
    @readers.key? io and awaits? io
  end

  def cancel_awaiting_readable(io)
    if awaits_readable? io
      detach_reader(io)
      resume(io, :cancelled)
    end
  end


  # Writable IO

  def attach_writer(io, &on_writable)
    @writers[io] = on_writable
  end

  def detach_writer(io)
    @writers.delete(io)
  end

  def await_writable(io, *args, &block)
    attach_writer(io) { detach_writer(io); resume(io, :writable) }
    await io, *args, &block
  end

  def awaits_writable?(io)
    @writers.key? io and awaits? io
  end

  def cancel_awaiting_writable(io)
    if awaits_writable? io
      detach_writer(io)
      resume(io, :cancelled)
    end
  end


  # Watching events

  def watch_events(*args)
    EventWatcher.new(self, *args)
  end
end