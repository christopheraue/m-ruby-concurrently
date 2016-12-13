module AggregatedTimers
  class Timer
    def initialize(seconds, opts = {}, &callback)
      raise Error, 'no block given' unless callback
      @seconds = seconds || @seconds
      @repeat = opts.fetch(:repeat, @repeat) || false
      @timeout_time = opts.fetch(:start_time, WallClock.now) + @seconds
      @callback = callback || @callback
    end

    def trigger
      raise Error, 'timer canceled' unless @callback
      @callback.call
      @repeat ? (@timeout_time += @seconds) : cancel
      true
    end

    def cancel
      @timeout_time = @seconds = @repeat = @callback = nil
      true
    end

    attr_reader :seconds

    attr_reader :timeout_time

    def waiting_time
      if @timeout_time
        waiting_time = @timeout_time - WallClock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def repeats?
      @repeat
    end

    def canceled?
      not waiting_time
    end

    def inspect
      "#<#{self.class}:0x#{'%014x' % __id__} #{waiting_time ? "waits another #{waiting_time.round(3)} seconds" : 'CANCELED'}>"
    end
  end
end