class IOEventLoop
  class RunQueue
    def initialize(loop)
      @loop = loop
      @items = []
    end

    def schedule(fiber, time, result = nil)
      entry = RunQueueEntry.new(fiber, time, result)
      index = bisect_left(@items, entry)
      @items.insert(index, entry)
      entry
    end

    def schedule_in(fiber, seconds, result = nil)
      schedule fiber, @loop.wall_clock.now+seconds, result
    end

    def waiting_time
      if next_scheduled = @items.reverse_each.find(&:scheduled?)
        waiting_time = next_scheduled.schedule_time - @loop.wall_clock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def run_pending
      index = bisect_left(@items, @loop.wall_clock.now)
      @items.pop(@items.length-index).reverse_each(&:scheduled_resume)
    end

    # Return the left-most index in a list of timers sorted in DESCENDING order
    # relative to a time or fiber e in O(log n).
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