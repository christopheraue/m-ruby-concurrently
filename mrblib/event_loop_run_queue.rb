module Concurrently
  # @api private
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

    DEFAULT_CANCEL_OPTS = { deferred_only: false }.freeze

    def initialize(loop)
      @loop = loop
      @cart_index = {}
      @deferred_track = []
      @immediate_track = []
    end

    def schedule_immediately(fiber, result = nil)
      cart = [fiber, false, result]
      @cart_index[fiber.hash] = cart
      @immediate_track << cart
    end

    def schedule_deferred(fiber, seconds, result = nil)
      cart = [fiber, @loop.lifetime+seconds, result]
      @cart_index[fiber.hash] = cart
      index = @deferred_track.bisect_left{ |cart_on_track| cart_on_track[TIME] <= cart[TIME] }
      @deferred_track.insert(index, cart)
    end

    def cancel(fiber, opts = DEFAULT_CANCEL_OPTS)
      if (cart = @cart_index[fiber.hash]) and (not opts[:deferred_only] or cart[TIME])
        cart[FIBER] = false
      end
    end

    def process_pending
      # Clear the fast track in the beginning so that carts added to it while
      # processing pending carts will be processed during the next iteration.
      processing = @immediate_track
      @immediate_track = []

      if @deferred_track.any?
        now = @loop.lifetime
        index = @deferred_track.bisect_left{ |cart| cart[TIME] <= now }
        @deferred_track.pop(@deferred_track.length-index).reverse_each do |cart|
          processing << cart
        end
      end

      processing.each do |cart|
        @cart_index.delete cart[FIBER].hash
        resume_fiber_from_event_loop! cart[FIBER], cart[RESULT] if cart[FIBER]
      end
    end

    def waiting_time
      if @immediate_track.any?
        0
      elsif next_cart = @deferred_track.reverse_each.find{ |cart| cart[FIBER] }
        waiting_time = next_cart[TIME] - @loop.lifetime
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def resume_fiber_from_event_loop!(fiber, result)
      case fiber
      when Proc::Fiber
        @current_fiber = fiber
        fiber.resume result
      else
        @current_fiber = nil
        Fiber.yield result
      end
    ensure
      @current_fiber = nil
    end

    def current_fiber
      @current_fiber || Fiber.current
    end
  end
end