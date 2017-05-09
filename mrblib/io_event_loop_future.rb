class IOEventLoop
  class Future
    def initialize(fiber, event_loop, run_queue)
      @fiber = fiber
      @event_loop = event_loop
      @run_queue = run_queue
      @evaluated = false
    end

    def result(opts = {})
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

        result, return_fiber = @event_loop.transfer

        if seconds
          @run_queue.cancel fiber
        end

        @requesting_fibers.delete fiber

        # If result is this very fiber it means this fiber has been evaluated
        # prematurely. In this case transfer back to the given return_fiber.
        (result == fiber) ? return_fiber.transfer : result
      end

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
        @fiber.transfer @fiber, Fiber.current
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