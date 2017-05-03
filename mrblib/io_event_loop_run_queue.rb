class IOEventLoop
  class RunQueue
    def initialize(loop)
      @loop = loop
      @items = []
    end

    def items
      @items.dup
    end

    def schedule(timer)
      index = bisect_left(@items, timer)
      @items.insert(index, timer)
    end

    def items?
      @items.delete_if(&:cancelled?).any?
    end

    def waiting_time
      if items?
        waiting_time = @items.last.resume_time - WallClock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def pending?
      waiting_time == 0
    end

    def pending
      @items.pop @items.length - bisect_left(@items, WallClock.now)
    end

    def after(seconds, &on_timeout)
      Concurrency.new(@loop, after: seconds, &on_timeout)
    end

    def every(seconds) # &on_timeout
      timer = after(seconds) { yield; timer.defer seconds }
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