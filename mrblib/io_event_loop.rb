Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop
  include CallbacksAttachable

  def initialize(*)
    @running = false
    @waiting = {}
    @once = []
    @timers = Timers.new
    @result_timers = {}
    @readers = {}
    @writers = {}
    @stop_and_raise_error = on(:error) { |_,e| stop CancelledError.new(e) }
  end

  def forgive_iteration_errors!
    @stop_and_raise_error.cancel
  end


  # Flow control

  def start
    @running = true

    while @running
      if @once.any?
        while fiber = @once.pop
          fiber.resume
        end
      else
        begin
          if (waiting_time = @timers.waiting_time) == 0
            @timers.triggerable.reverse_each(&:trigger)
          elsif waiting_time or @readers.any? or @writers.any?
            if selected = IO.select(@readers.keys, @writers.keys, nil, waiting_time)
              selected[0].each{ |readable_io| @readers[readable_io].call } unless selected[0].empty?
              selected[1].each{ |writable_io| @writers[writable_io].call } unless selected[1].empty?
            end
          else
            stop # would block indefinitely otherwise
          end
        rescue Exception => e
          trigger :error, e
        end
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
    @once.unshift RescuedFiber.new(self, &block)
  end

  def await(id, opts = {})
    if timeout = opts.fetch(:within, false)
      timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{timeout} second(s)"))
      @result_timers[id] = @timers.after(timeout){ resume(id, timeout_result) }
    end

    case @waiting[id] = ::Fiber.current
    when Fiber
      result = ::Fiber.yield
      (CancelledError === result) ? raise(result) : result
    else
      start
    end
  end

  def resume(id, result)
    @result_timers.delete(id).cancel if @result_timers.key? id

    case fiber = @waiting.delete(id)
    when nil
      raise UnknownWaitingIdError, "unknown waiting id #{id.inspect}"
    when Fiber
      fiber.resume result
    else
      stop result
    end
  end

  def awaits?(id)
    @waiting.key? id
  end

  def cancel(id, reason = "waiting for id #{id.inspect} cancelled")
    resume id, CancelledError.new(reason)
    :cancelled
  end


  # Timers

  attr_reader :timers


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