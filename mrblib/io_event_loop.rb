Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop < FiberedEventLoop
  def initialize
    @timers = Timers.new
    @result_timers = {}
    @readers = {}
    @writers = {}

    super do
      waiting_time = @timers.waiting_time
      @timers.triggerable.each{ |timer| once{ timer.trigger } } if waiting_time == 0

      yield if block_given?

      if once_pending?
        next
      elsif @readers.empty? and @writers.empty? and not waiting_time
        stop # would block indefinitely otherwise
      elsif selected = IO.select(@readers.keys, @writers.keys, nil, waiting_time)
        selected[0].each{ |readable_io| once &@readers[readable_io].last } unless selected[0].empty?
        selected[1].each{ |writable_io| once &@writers[writable_io].last } unless selected[1].empty?
      else
        next
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

  def wait_for_result(id, timeout = nil) # &on_timeout
    @result_timers[id] = @timers.after(timeout){ hand_result_to(@id, yield) } if timeout
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