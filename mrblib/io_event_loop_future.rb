class IOEventLoop
  class Future
    def initialize(loop, run_queue, fiber)
      @loop = loop
      @run_queue = run_queue
      @run_queue.schedule_in 0, fiber, self
      @evaluated = false
    end

    def result(opts = {})
      if @evaluated
        result = @result
      else
        @requesting_fiber = Fiber.current

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
          timeout = @run_queue.schedule_in seconds, Fiber.current, timeout_result
        end

        result = @loop.resume

        @requesting_fiber = nil

        if seconds
          timeout.cancel
        end
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
        @run_queue.schedule_in 0, @requesting_fiber, result if @requesting_fiber
        :evaluated
      end
    end

    def cancel(reason = "waiting cancelled")
      evaluate_to CancelledError.new reason
      :cancelled
    end
  end
end