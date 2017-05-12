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
      index = @cart_track.bisect_left{ |cart| cart.time <= time }
      @cart_track.insert(index, cart)
    end

    def cancel(fiber)
      @cart_pool.unload_by_fiber fiber
    end

    def process_pending
      now = @wall_clock.now
      index = @cart_track.bisect_left{ |cart| cart.time <= now }
      @cart_track.pop(@cart_track.length-index).reverse_each(&:unload_and_process)
    end

    def waiting_time
      if next_scheduled = @cart_track.reverse_each.find(&:loaded?)
        waiting_time = next_scheduled.time - @wall_clock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end
  end
end