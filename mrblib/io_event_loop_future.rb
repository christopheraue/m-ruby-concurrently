class IOEventLoop
  class Future
    def initialize(loop, run_queue, fiber)
      @loop = loop
      @run_queue = run_queue
      @fiber = fiber
      @requesting_fibers = {}
      @evaluated = false
    end

    def result(opts = {})
      if @evaluated
        result = @result
      else
        fiber = Fiber.current
        @requesting_fibers.store fiber, true

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
          @run_queue.schedule fiber, seconds, timeout_result
        end

        result = @loop.resume

        if seconds
          @run_queue.cancel fiber
        end

        @requesting_fibers.delete fiber
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
        @run_queue.cancel @fiber
        @requesting_fibers.each_key{ |fiber| @run_queue.schedule fiber, 0, result }
        :evaluated
      end
    end

    def cancel(reason = "waiting cancelled")
      evaluate_to CancelledError.new reason
      :cancelled
    end
  end
end