module Concurrently
  class EventLoop::RunQueue
    # The items of the run queue are called carts. Carts are simple arrays
    # with the following layout: [fiber, time, result]
    FIBER = 0; TIME = 1; RESULT = 2

    # There are two tracks. The fast track and the regular cart track. The
    # fast track exists for fibers to be scheduled immediately. Having a
    # dedicated track lets us just push carts to the track in the order they
    # appear. This saves us the rather expensive #bisect_left computation where
    # on the regular cart track to insert the cart.

    # The additional cart index exists so carts can be cancelled by their
    # fiber. Cancelled carts have their fiber set to false.

    def initialize(loop)
      @loop = loop
      @cart_index = {}
      @cart_track = []
      @fast_track = []
    end

    def schedule_now(fiber, result = nil)
      cart = [fiber, nil, result]
      @cart_index[fiber.hash] = cart
      @fast_track << cart
    end

    def schedule(fiber, seconds, result = nil)
      cart = [fiber, @loop.lifetime+seconds, result]
      @cart_index[fiber.hash] = cart
      index = @cart_track.bisect_left{ |cart_on_track| cart_on_track[TIME] <= cart[TIME] }
      @cart_track.insert(index, cart)
    end

    def cancel(fiber)
      if cart = @cart_index.delete(fiber.hash)
        cart[FIBER] = false
      end
    end

    def process_pending
      # Clear the fast track in the beginning so that carts added to it while
      # processing pending carts will be processed during the next iteration.
      processing = @fast_track
      @fast_track = []

      if @cart_track.any?
        now = @loop.lifetime
        index = @cart_track.bisect_left{ |cart| cart[TIME] <= now }
        @cart_track.pop(@cart_track.length-index).reverse_each do |cart|
          processing << cart
        end
      end

      processing.each do |cart|
        @cart_index.delete cart[FIBER].hash
        cart[FIBER].resume_from_event_loop! cart[RESULT] if cart[FIBER]
      end
    end

    def waiting_time
      if @fast_track.any?
        0
      elsif next_cart = @cart_track.reverse_each.find{ |cart| cart[FIBER] }
        waiting_time = next_cart[TIME] - @loop.lifetime
        waiting_time < 0 ? 0 : waiting_time
      end
    end
  end
end