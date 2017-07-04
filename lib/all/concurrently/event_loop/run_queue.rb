module Concurrently
  # @private
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

    class Track < Array
      def bisect_left
        bsearch_index{ |item| yield item } || length
      end
    end

    def initialize(loop)
      @loop = loop
      @deferred_track = Track.new
      @immediate_track = Track.new
    end

    def schedule_immediately(evaluation, result = nil, cancellable = true)
      cart = [evaluation, false, result]
      evaluation.instance_variable_set :@__cart__, cart if cancellable
      @immediate_track << cart
    end

    def schedule_deferred(evaluation, seconds, result = nil)
      cart = [evaluation, @loop.lifetime+seconds, result]
      evaluation.instance_variable_set :@__cart__, cart
      index = @deferred_track.bisect_left{ |tcart| tcart[TIME] <= cart[TIME] }
      @deferred_track.insert(index, cart)
    end

    def cancel(evaluation, only_if_deferred = false)
      if (cart = evaluation.instance_variable_get :@__cart__) and (not only_if_deferred or cart[TIME])
        cart[EVALUATION] = false
      end
    end

    def process_pending
      # Clear the fast track in the beginning so that carts added to it while
      # processing pending carts will be processed during the next iteration.
      processing = @immediate_track
      @immediate_track = []

      if @deferred_track.size > 0
        now = @loop.lifetime
        index = @deferred_track.bisect_left{ |cart| cart[TIME] <= now }
        @deferred_track.pop(@deferred_track.length-index).reverse_each do |cart|
          processing << cart
        end
      end

      processing.each do |cart|
        evaluation = cart[EVALUATION]
        resume_evaluation! evaluation, cart[RESULT] if evaluation
      end
    end

    def waiting_time
      if @immediate_track.size > 0
        0
      elsif next_cart = @deferred_track.reverse_each.find{ |cart| cart[EVALUATION] }
        waiting_time = next_cart[TIME] - @loop.lifetime
        waiting_time < 0 ? 0 : waiting_time
      else
        Float::INFINITY
      end
    end

    def resume_evaluation!(evaluation, result)
      previous_evaluation = @current_evaluation

      case evaluation
      when Proc::Fiber # this will only happen when calling Concurrently::Proc#call_and_forget
        @current_evaluation = nil
        evaluation.resume result
      when Proc::Evaluation
        @current_evaluation = evaluation
        evaluation.fiber.resume result
      else
        @current_evaluation = nil
        Fiber.yield result
      end
    ensure
      @current_evaluation = previous_evaluation
    end

    # only needed in Concurrently::Proc#call_nonblock
    attr_accessor :current_evaluation
    attr_writer :evaluation_class

    def current_evaluation
      @current_evaluation ||= case fiber = Fiber.current
      when Proc::Fiber
        (@evaluation_class || Proc::Evaluation).new fiber
      else
        Evaluation.new fiber
      end
    end
  end
end