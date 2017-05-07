class IOEventLoop
  class RunQueue
    def initialize
      @wall_clock = WallClock.new
      @cart_track = []
      @cart_index = {}
    end

    def schedule(fiber, seconds, result = nil)
      cart = Cart.new(fiber, @wall_clock.now+seconds, result)
      index = bisect_left(@cart_track, cart.time)
      @cart_track.insert(index, cart)
      @cart_index[fiber] = cart
    end

    def cancel(fiber)
      if cart = @cart_index.delete(fiber)
        cart.cancel
      end
    end

    def waiting_time
      if next_scheduled = @cart_track.reverse_each.find(&:active?)
        waiting_time = next_scheduled.time - @wall_clock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def process_pending
      index = bisect_left(@cart_track, @wall_clock.now)
      @cart_track.pop(@cart_track.length-index).reverse_each(&:process)
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