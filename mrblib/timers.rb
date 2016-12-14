module IOEventLoop
  class Timers
    def initialize
      @timers = []
    end

    def after(seconds, &on_timeout)
      Timer.new(seconds, timers: self, &on_timeout)
    end

    def every(seconds, &on_timeout)
      Timer.new(seconds, timers: self, repeat: true, &on_timeout)
    end

    def attach_to(parent_timers)
      @parent_timers = parent_timers
    end

    def schedule(timer)
      if @parent_timers
        @parent_timers.schedule timer
      else
        index = bisect_left(@timers, timer)
        @timers.insert(index, timer)
      end
    end

    def waiting_time
      @timers.pop while @timers.last && @timers.last.canceled?
      @timers.last && @timers.last.waiting_time
    end

    def triggerable
      trigger_threshold = bisect_left(@timers, WallClock.now)
      @timers.pop(@timers.length - trigger_threshold).delete_if(&:canceled?)
    end

    # Return the left-most index in a list of timers a corresponding to a
    # cutoff time or timer e in O(log n), assuming a is sorted in descending
    # order.
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