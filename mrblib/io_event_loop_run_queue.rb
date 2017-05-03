class IOEventLoop
  class RunQueue
    def initialize
      @items = []
    end

    def schedule(timer)
      index = bisect_left(@items, timer)
      @items.insert(index, timer)
    end

    def waiting_time
      if last = @items.delete_if(&:cancelled?).last
        waiting_time = last.resume_time - WallClock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def pending
      @items.pop @items.length - bisect_left(@items, WallClock.now)
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