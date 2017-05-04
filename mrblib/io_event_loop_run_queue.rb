class IOEventLoop
  class RunQueue
    def initialize(loop)
      @loop = loop
      @items = []
    end

    def schedule(concurrency)
      index = bisect_left(@items, concurrency)
      @items.insert(index, concurrency)
    end

    def waiting_time
      if last = @items.delete_if(&:cancelled?).last
        waiting_time = last.schedule_time - @loop.wall_clock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def run_pending
      index = bisect_left(@items, @loop.wall_clock.now)
      @items.pop(@items.length-index).reverse_each(&:scheduled_resume)
    end

    # Return the left-most index in a list of timers sorted in DESCENDING order
    # relative to a time or concurrency e in O(log n).
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