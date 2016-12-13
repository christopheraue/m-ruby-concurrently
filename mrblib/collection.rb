module AggregatedTimers
  class Collection
    def initialize
      @timers = []
    end

    def after(seconds, &on_timeout)
      Timer.new(seconds, collection: self, &on_timeout)
    end

    def every(seconds, &on_timeout)
      Timer.new(seconds, collection: self, repeat: true, &on_timeout)
    end

    def attach_to(collection)
      @collection = collection
    end

    def schedule(timer)
      if @collection
        @collection.schedule timer
      else
        index = bisect_left(@timers, timer)
        @timers.insert(index, timer)
      end
    end

    def waiting_time
      @timers.pop while @timers.last && @timers.last.canceled?
      @timers.last && @timers.last.waiting_time
    end

    def trigger
      @timers.pop while @timers.last && @timers.last.canceled?
      if @timers.last && @timers.last.waiting_time == 0
        @timers.pop.trigger
      else
        false
      end
    end

    # Return the left-most index where to insert timer e, in a list a, assuming
    # a is sorted in descending order in O(log n).
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