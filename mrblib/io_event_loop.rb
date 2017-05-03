Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize(*)
    @running = false
    @stop_and_raise_error = on(:error) { |_,e| stop CancelledError.new(e) }

    @concurrencies = {}
    @waiting_concurrencies = {}

    @run_queue = RunQueue.new
    @readers = {}
    @writers = {}
  end

  def forgive_iteration_errors!
    @stop_and_raise_error.cancel
  end


  # Flow control

  attr_reader :concurrencies, :run_queue

  def start
    @running = true

    while @running
      if (waiting_time = @run_queue.waiting_time) == 0
        @run_queue.pending.reverse_each{ |concurrency| concurrency.resume_with true }
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
    Concurrency.new(self, &block)
    start unless @running
  end

  def await(id, opts = {})
    concurrency = @concurrencies[Fiber.current]

    timer = if timeout = opts.fetch(:within, false)
      timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{timeout} second(s)"))
      after(timeout){ resume(id, timeout_result) }
    else
      nil
    end

    @waiting_concurrencies[id] = { concurrency: concurrency, timer: timer }

    if concurrency
      concurrency.await_result
    else
      start
    end
  end

  def resume(id, result)
    if waiting = @waiting_concurrencies.delete(id)
      if timer = waiting[:timer]
        timer.cancel
      end

      if concurrency = waiting[:concurrency]
        concurrency.resume_with result
      else
        stop result
      end
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
    Concurrency.new(self, after: seconds, &on_timeout)
  end

  def every(seconds) # &on_timeout
    timer = after(seconds) { yield; timer.defer seconds }
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