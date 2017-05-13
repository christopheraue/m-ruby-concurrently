class IOEventLoop
  class RunQueue
    def initialize
      @wall_clock = WallClock.new
      @cart_pool = CartPool.new
      @cart_track = []
      @fast_track = []
    end

    def schedule(fiber, seconds, result = nil)
      if seconds == 0
        @fast_track << @cart_pool.take_and_load_with(fiber, nil, result)
      else
        time = @wall_clock.now+seconds
        cart = @cart_pool.take_and_load_with(fiber, time, result)
        index = @cart_track.bisect_left{ |cart| cart.time <= time }
        @cart_track.insert(index, cart)
      end
    end

    def cancel(fiber)
      @cart_pool.unload_by_fiber fiber
    end

    def process_pending
      processing = @fast_track
      @fast_track = []
      processing.each(&:unload_and_process)

      if @cart_track.any?
        now = @wall_clock.now
        index = @cart_track.bisect_left{ |cart| cart.time <= now }
        @cart_track.pop(@cart_track.length-index).reverse_each(&:unload_and_process)
      end
    end

    def waiting_time
      if @fast_track.any?
        0
      elsif next_scheduled = @cart_track.reverse_each.find(&:loaded?)
        waiting_time = next_scheduled.time - @wall_clock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end
  end
end