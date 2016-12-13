module AggregatedTimers
  class Timer
    include CallbacksAttachable

    def initialize(seconds, opts = {}, &callback)
      raise Error, 'no block given' unless callback
      restart(seconds, opts, &callback)
    end

    def restart(seconds = @seconds, opts = {}, &new_callback)
      @seconds = seconds || @seconds
      @repeat = opts.fetch(:repeat, @repeat) || false
      @timeout_time = opts.fetch(:start_time, WallClock.now) + @seconds
      @callback = new_callback || @callback
      trigger_event :restart, self
    end

    def cancel
      @seconds = nil
      @timeout_time = nil
      @repeat = nil
      @callback = nil
      trigger_event :cancel, self
    end

    def trigger
      raise Error, 'timer canceled' unless @callback
      @callback.call
      @repeat ? restart(@seconds, start_time: @timeout_time) : cancel
    end

    attr_reader :seconds

    attr_reader :timeout_time

    def waiting_time
      if @callback
        @timeout_time - WallClock.now
      else
        nil
      end
    end

    def repeats?
      @repeat
    end

    def canceled?
      not @callback
    end

    def inspect
      "#<#{self.class}:0x#{'%014x' % __id__} #{canceled? ? 'CANCELED' : "waits another #{waiting_time.round(3)} seconds"}>"
    end
  end
end