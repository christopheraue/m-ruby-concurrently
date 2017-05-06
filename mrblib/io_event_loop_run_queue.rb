class IOEventLoop
  class RunQueue
    def initialize(loop)
      @loop = loop
      @carts = []
    end

    def schedule(fiber, time, result = nil)
      entry = Cart.new(fiber, time, result)
      index = bisect_left(@carts, entry)
      @carts.insert(index, entry)
      entry
    end

    def schedule_in(seconds, fiber, result = nil)
      schedule fiber, @loop.wall_clock.now+seconds, result
    end

    def waiting_time
      if next_scheduled = @carts.reverse_each.find(&:active?)
        waiting_time = next_scheduled.time - @loop.wall_clock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def run_pending
      index = bisect_left(@carts, @loop.wall_clock.now)
      @carts.pop(@carts.length-index).reverse_each(&:process)
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