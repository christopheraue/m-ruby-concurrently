class IOEventLoop
  class Timers
    def initialize
      @timers = []
    end

    def timers
      @timers.dup
    end

    def after(seconds, &on_timeout)
      Timer.new(seconds, timers: self, &on_timeout)
    end

    def every(seconds, &on_timeout)
      Timer.new(seconds, timers: self, repeat: true, &on_timeout)
    end

    def schedule(timer)
      index = bisect_left(@timers, timer)
      @timers.insert(index, timer)
    end

    def waiting_time
      @timers.pop while last = @timers.last and last.cancelled?
      last.waiting_time if last
    end

    def triggerable
      trigger_threshold = bisect_left(@timers, WallClock.now)
      @timers.pop(@timers.length - trigger_threshold)
    end

    # Return the left-most index in a list of timers sorted in DESCENDING order
    # relative to a time or timer e in O(log n).
    # Shamelessly copied from https://github.com/celluloid/timers/blob/master/lib/timers/events.rb
    private def bisect_left(a, e, l = 0, u = a.length)
      while l < u
        m = l + (u - l).div(2)

        if a[m] > e
          l = m + 1
        else
          u = m
        end
      end

      l
    end
  end
end