class IOEventLoop
  class Timer
    def initialize(seconds, callback)
      raise Error, 'no block given' unless callback
      @seconds = seconds
      @callback = callback
      @timeout_time = WallClock.now + @seconds
      @cancelled = false
    end

    attr_reader :seconds
    attr_reader :timeout_time
    alias_method :to_f, :timeout_time

    def waiting_time
      unless @cancelled
        waiting_time = @timeout_time - WallClock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def trigger
      if @cancelled
        false
      else
        cancel
        @callback.call
        true
      end
    end

    def cancel
      @cancelled = true
    end

    def cancelled?
      @cancelled
    end

    def repeat
      @timeout_time += @seconds
      @cancelled = false
      true
    end

    def >(time_or_timer)
      @timeout_time > time_or_timer.to_f
    end

    def inspect
      "#<#{self.class}:0x#{'%014x' % __id__} #{waiting_time ? "waits another #{waiting_time.round(3)} seconds" : 'CANCELED'}>"
    end
  end
end