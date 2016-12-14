Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop < FiberedEventLoop
  def initialize
    @timers = Timers.new
    @readers = []
    @writers = []

    super do
      if @timers.waiting_time == 0
        @timers.triggerable.each{ |timer| fibered{ timer.trigger } }
      end

      if selected = IO.select(@readers, @writers, nil, @timers.waiting_time)
        selected[0].each{ |readable| fibered{ hand_result_to readable, @readers.delete(readable) } }
        selected[1].each{ |writable| fibered{ hand_result_to writable, @writers.delete(writable) } }
      end

      stop if @readers.empty? and @writers.empty? and not @timers.waiting_time
    end
  end

  attr_reader :timers

  def wait_for_readable(channel)
    @readers << channel
    wait_for_result channel
  end

  def wait_for_writable(channel)
    @writers << channel
    wait_for_result channel
  end
end