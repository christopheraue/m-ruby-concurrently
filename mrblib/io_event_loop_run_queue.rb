class IOEventLoop
  class RunQueue
    def initialize
      @wall_clock = WallClock.new
      @cart_pool = CartPool.new
      @cart_track = []
    end

    def schedule(fiber, seconds, result = nil)
      time = @wall_clock.now+seconds
      cart = @cart_pool.take_and_load_with(fiber, time, result)
      index = bisect_left(@cart_track, time)
      @cart_track.insert(index, cart)
    end

    def cancel(fiber)
      @cart_pool.unload_by_fiber fiber
    end

    def process_pending
      index = bisect_left(@cart_track, @wall_clock.now)
      @cart_track.pop(@cart_track.length-index).reverse_each(&:unload_and_process)
    end

    def waiting_time
      if next_scheduled = @cart_track.reverse_each.find(&:loaded?)
        waiting_time = next_scheduled.time - @wall_clock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    # Return the left-most index in a list of carts sorted in DESCENDING order
    # relative to a time e in O(log n).
    # Shamelessly copied from https://github.com/socketry/timers/blob/75b71e402025cb289eccc0e733fac9bd7edde925/lib/timers/events.rb#L97
    private def bisect_left(a, e, l = 0, u = a.length)
      while l < u
        m = l + (u - l).div(2)

        if a[m].time > e
          l = m + 1
        else
          u = m
        end
      end

      l
    end
  end
end