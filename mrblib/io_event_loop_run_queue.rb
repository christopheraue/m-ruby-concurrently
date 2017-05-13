class IOEventLoop
  class RunQueue
    # The items of the run queue are called carts. Carts are simple arrays
    # with the following layout: [active, fiber, time, result]
    ACTIVE = 0; FIBER = 1; TIME = 2; RESULT = 3

    # There are two tracks. The fast track and the regular cart track. The
    # fast track exists for fibers to be scheduled immediately. Having a
    # dedicated track lets us just push carts to the track in the order they
    # appear. This saves us the rather expensive #bisect_left computation where
    # on the regular cart track to insert the cart.

    # The additional cart index exists so carts can be cancelled by their
    # fiber.

    def initialize(wall_clock)
      @wall_clock = wall_clock
      @cart_index = {}
      @cart_track = []
      @fast_track = []
    end

    def schedule_now(fiber, result = nil)
      cart = [true, fiber, nil, result]
      @cart_index[fiber.hash] = cart
      @fast_track << cart
    end

    def schedule(fiber, seconds, result = nil)
      cart = [true, fiber, @wall_clock.now+seconds, result]
      @cart_index[fiber.hash] = cart
      index = @cart_track.bisect_left{ |cart_on_track| cart_on_track[TIME] <= cart[TIME] }
      @cart_track.insert(index, cart)
    end

    def cancel(fiber)
      if cart = @cart_index[fiber.hash]
        cart[ACTIVE] = false
      end
    end

    def process_pending
      processing = @fast_track
      @fast_track = []

      if @cart_track.any?
        now = @wall_clock.now
        index = @cart_track.bisect_left{ |cart| cart[TIME] <= now }
        @cart_track.pop(@cart_track.length-index).reverse_each do |cart|
          processing << cart
        end
      end

      processing.each do |cart|
        @cart_index.delete cart[FIBER].hash

        if cart[ACTIVE]
          case fiber = cart[FIBER]
          when ConcurrentBlock::Fiber
            fiber.resume cart[RESULT]
          else
            Fiber.yield cart[RESULT] # leave event loop and yield to root fiber
          end
        end
      end
    end

    def waiting_time
      if @fast_track.any?
        0
      elsif next_cart = @cart_track.reverse_each.find{ |cart| cart[ACTIVE] }
        waiting_time = next_cart[TIME] - @wall_clock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end
  end
end