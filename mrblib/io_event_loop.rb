Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop < FiberedEventLoop
  def initialize(*)
    @timers = Timers.new
    @result_timers = {}
    @readers = {}
    @writers = {}

    super do
      waiting_time = @timers.waiting_time
      @timers.triggerable.each{ |timer| once{ timer.trigger } } if waiting_time == 0

      trigger :iteration

      if once_pending?
        next
      elsif @readers.empty? and @writers.empty? and not waiting_time
        stop # would block indefinitely otherwise
      elsif selected = IO.select(@readers.keys, @writers.keys, nil, waiting_time)
        selected[0].each{ |readable_io| once(&@readers[readable_io]) } unless selected[0].empty?
        selected[1].each{ |writable_io| once(&@writers[writable_io]) } unless selected[1].empty?
      else
        next
      end
    end
  end

  attr_reader :timers

  def attach_reader(io, &on_readable)
    @readers[io] = on_readable
  end

  def attach_writer(io, &on_writable)
    @writers[io] = on_writable
  end

  def detach_reader(io)
    @readers.delete(io)
  end

  def detach_writer(io)
    @writers.delete(io)
  end

  def await(id, timeout = nil) # &on_timeout
    @result_timers[id] = @timers.after(timeout){ resume(id, yield) } if timeout
    super id
  end

  def resume(id, result)
    @result_timers.delete(id).cancel if @result_timers.key? id
    super
  end

  def wait_for_readable(io, *args, &block)
    attach_reader(io) { detach_reader(io); resume(io, :readable) }
    await io, *args, &block
  end

  def waits_for_readable?(io)
    @readers.key? io and awaits? io
  end

  def cancel_waiting_for_readable(io)
    if waits_for_readable? io
      detach_reader(io)
      resume(io, :canceled)
    end
  end

  def wait_for_writable(io, *args, &block)
    attach_writer(io) { detach_writer(io); resume(io, :writable) }
    await io, *args, &block
  end

  def waits_for_writable?(io)
    @writers.key? io and awaits? io
  end

  def cancel_waiting_for_writable(io)
    if waits_for_writable? io
      detach_writer(io)
      resume(io, :canceled)
    end
  end
end