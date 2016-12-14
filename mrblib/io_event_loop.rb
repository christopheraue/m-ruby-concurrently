Object.__send__(:remove_const, :IOEventLoop) if Object.const_defined? :IOEventLoop

class IOEventLoop < FiberedEventLoop
  def initialize
    @timers = Timers.new
    @readers = []
    @writers = []

    super do
      @timers.triggerable.each{ |timer| fibered{ timer.trigger } } if @timers.waiting_time == 0

      if fibered_registered?
        next
      elsif @readers.empty? and @writers.empty? and not @timers.waiting_time
        stop
      elsif selected = IO.select(@readers, @writers, nil, @timers.waiting_time)
        selected[0].each{ |readable| fibered{ hand_result_to readable, @readers.delete(readable) } }
        selected[1].each{ |writable| fibered{ hand_result_to writable, @writers.delete(writable) } }
      end
    end
  end

  attr_reader :timers

  def wait_for(io, mode)
    bucket = (mode == :w) ? @writers : @readers
    bucket << io
    wait_for_result io
  end
end