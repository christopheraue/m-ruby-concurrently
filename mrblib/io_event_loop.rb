Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop < FiberedEventLoop
  def initialize
    @timers = Timers.new
    @result_timers = {}
    @readers = {}
    @writers = {}

    super do
      @timers.triggerable.each{ |timer| fibered{ timer.trigger } } if @timers.waiting_time == 0

      if fibered_registered?
        next
      elsif @readers.empty? and @writers.empty? and not @timers.waiting_time
        stop
      elsif selected = IO.select(@readers.keys, @writers.keys, nil, @timers.waiting_time)
        selected[0].each{ |readable_io| fibered &@readers[readable_io].last }
        selected[1].each{ |writable_io| fibered &@writers[writable_io].last }
      end
    end
  end

  attr_reader :timers

  def attach_reader(io, &on_readable)
    @readers[io] ||= []
    @readers[io] << on_readable
  end

  def attach_writer(io, &on_writable)
    @writers[io] ||= []
    @writers[io] << on_writable
  end

  def detach_reader(io)
    @readers[io].pop
    @readers.delete(io) if @readers[io].empty?
  end

  def detach_writer(io)
    @writers[io].pop
    @writers.delete(io) if @writers[io].empty?
  end

  def wait_for_result(id, timeout = nil, &on_timeout)
    @result_timers[id] = @timers.after(timeout, &on_timeout) if timeout
    super id
  end

  def hand_result_to(id, result)
    @result_timers.delete(id).cancel if @result_timers.key? id
    super
  end

  def wait_for_readable(io, *args, &block)
    attach_reader(io) { detach_reader(io); hand_result_to(io, :readable) }
    wait_for_result io, *args, &block
  end

  def wait_for_writable(io, *args, &block)
    attach_writer(io) { detach_writer(io); hand_result_to(io, :writable) }
    wait_for_result io, *args, &block
  end
end