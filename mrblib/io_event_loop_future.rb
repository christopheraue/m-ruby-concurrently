class IOEventLoop
  class Future
    def initialize(loop, run_queue, fiber)
      @loop = loop
      @run_queue = run_queue
      @run_queue.schedule_in 0, fiber, self
      @requesting_fibers = []
    end

    def result(opts = {})
      unless instance_variable_defined? :@result
        @requesting_fibers.push Fiber.current

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
          timeout = @run_queue.schedule_in seconds, Fiber.current, timeout_result
        end

        @result = @loop.resume

        if seconds
          timeout.cancel
        end
      end

      (Exception === @result) ? (raise @result) : @result
    end

    def evaluated?
      instance_variable_defined? :@result
    end

    def evaluate_to(result)
      @result = result
      @requesting_fibers.each{ |fiber| @run_queue.schedule_in 0, fiber, result }.clear
      @loop.resume
    end

    def cancel(reason = "waiting cancelled")
      evaluate_to CancelledError.new reason
    end
  end
end