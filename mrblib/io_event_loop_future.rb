class IOEventLoop
  class Future
    def initialize(fiber, event_loop, run_queue)
      @fiber = fiber
      @event_loop = event_loop
      @run_queue = run_queue
      @evaluated = false
    end

    def result(opts = {}) # &with_result
      if @evaluated
        result = @result
      else
        fiber = Fiber.current

        @requesting_fibers ||= {}
        @requesting_fibers.store(fiber, true)

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("evaluation timed out after #{seconds} second(s)"))
          @run_queue.schedule(fiber, seconds, timeout_result)
        end

        result = @event_loop.transfer

        if seconds
          @run_queue.cancel fiber
        end

        @requesting_fibers.delete fiber

        # If result is a fiber it means this fiber has been evaluated prematurely.
        # In this case transfer back to the given result fiber.
        (Fiber === result) ? result.transfer : result
      end

      result = yield result if block_given?

      (Exception === result) ? (raise result) : result
    end

    attr_reader :evaluated
    alias evaluated? evaluated
    undef evaluated

    def evaluate_to(result)
      if @evaluated
        raise Error, "already evaluated"
      else
        @result = result
        @evaluated = true

        # Cancel @fiber unless we are already in it. If we are in @fiber, this
        # is a no op.
        @fiber.transfer Fiber.current

        @requesting_fibers.each_key{ |fiber| @run_queue.schedule(fiber, 0, result) } if @requesting_fibers
        :evaluated
      end
    end

    def cancel(reason = "evaluation cancelled")
      evaluate_to CancelledError.new(reason)
      :cancelled
    end
  end
end