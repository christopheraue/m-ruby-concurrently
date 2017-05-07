class IOEventLoop
  class RunQueue
    def initialize(loop)
      @loop = loop
      @cart_track = []
      @cart_index = {}
    end

    def schedule(fiber, seconds, result = nil)
      cart = Cart.new(fiber, @loop.wall_clock.now+seconds, result)
      index = bisect_left(@cart_track, cart)
      @cart_track.insert(index, cart)
      @cart_index[fiber] = cart
    end

    def cancel(fiber)
      @cart_index.delete(fiber).cancel
    end

    def waiting_time
      if next_scheduled = @cart_track.reverse_each.find(&:active?)
        waiting_time = next_scheduled.time - @loop.wall_clock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def process_pending
      index = bisect_left(@cart_track, @loop.wall_clock.now)
      @cart_track.pop(@cart_track.length-index).reverse_each(&:process)
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