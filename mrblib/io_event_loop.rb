Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop < FiberedEventLoop
  def initialize
    @timers = Timers.new
    @readers = {}
    @writers = {}

    super do
      @timers.triggerable.each{ |timer| fibered{ timer.trigger } } if @timers.waiting_time == 0

      if fibered_registered?
        next
      elsif @readers.empty? and @writers.empty? and not @timers.waiting_time
        stop
      elsif selected = IO.select(@readers.keys, @writers.keys, nil, @timers.waiting_time)
        selected[0].each{ |readable_io| fibered &@readers[readable_io] }
        selected[1].each{ |writable_io| fibered &@writers[writable_io] }
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

  def await_read(io)
    attach_reader(io) { hand_result_to io, detach_reader(io) }
    wait_for_result io
  end

  def await_write(io)
    attach_writer(io) { hand_result_to io, detach_writer(io) }
    wait_for_result io
  end
end