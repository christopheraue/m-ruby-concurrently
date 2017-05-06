class IOEventLoop
  class Future
    def initialize(loop, run_queue, fiber)
      @loop = loop
      @run_queue = run_queue
      @run_queue.schedule_in 0, fiber, self
      @requesting_fibers = []
      @evaluated = false
    end

    def result(opts = {})
      if @evaluated
        result = @result
      else
        @requesting_fibers.push Fiber.current

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
          timeout = @run_queue.schedule_in seconds, Fiber.current, timeout_result
        end

        result = @loop.resume

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
      @result = result
      @evaluated = true
      @requesting_fibers.each{ |fiber| @run_queue.schedule_in 0, fiber, result }.clear
      @loop.resume
    end

    def cancel(reason = "waiting cancelled")
      evaluate_to CancelledError.new reason
    end
  end
end