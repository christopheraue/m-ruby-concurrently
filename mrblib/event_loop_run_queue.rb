module Concurrently
  # @api private
  class EventLoop::RunQueue
    # The items of the run queue are called carts. Carts are simple arrays
    # with the following layout: [evaluation, time, result]
    EVALUATION = 0; TIME = 1; RESULT = 2

    # There are two tracks. The fast track and the regular cart track. The
    # fast track exists for evaluations to be scheduled immediately. Having a
    # dedicated track lets us just push carts to the track in the order they
    # appear. This saves us the rather expensive #bisect_left computation where
    # on the regular cart track to insert the cart.

    # The additional cart index exists so carts can be cancelled by their
    # evaluation. Cancelled carts have their evaluation set to false.

    DEFAULT_CANCEL_OPTS = { deferred_only: false }.freeze

    def initialize(loop)
      @loop = loop
      @cart_index = {}
      @deferred_track = []
      @immediate_track = []
    end

    def schedule_immediately(evaluation, result = nil)
      cart = [evaluation, false, result]
      @cart_index[evaluation.hash] = cart
      @immediate_track << cart
    end

    def schedule_deferred(evaluation, seconds, result = nil)
      cart = [evaluation, @loop.lifetime+seconds, result]
      @cart_index[evaluation.hash] = cart
      index = @deferred_track.bisect_left{ |cart_on_track| cart_on_track[TIME] <= cart[TIME] }
      @deferred_track.insert(index, cart)
    end

    def cancel(evaluation, opts = DEFAULT_CANCEL_OPTS)
      if (cart = @cart_index[evaluation.hash]) and (not opts[:deferred_only] or cart[TIME])
        cart[EVALUATION] = false
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
        @cart_index.delete cart[EVALUATION].hash
        resume_evaluation_from_event_loop! cart[EVALUATION], cart[RESULT] if cart[EVALUATION]
      end
    end

    def waiting_time
      if @immediate_track.any?
        0
      elsif next_cart = @deferred_track.reverse_each.find{ |cart| cart[EVALUATION] }
        waiting_time = next_cart[TIME] - @loop.lifetime
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def resume_evaluation_from_event_loop!(evaluation, result)
      previous_evaluation = @current_evaluation
      case evaluation
      when Proc::Evaluation
        @current_evaluation = evaluation
        evaluation.instance_variable_get(:@fiber).resume result
      else
        @current_evaluation = nil
        Fiber.yield result
      end
    ensure
      @current_evaluation = previous_evaluation
    end

    def current_evaluation
      @current_evaluation ||= Evaluation.new(Fiber.current)
    end
  end
end