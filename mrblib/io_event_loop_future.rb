class IOEventLoop
  class Future
    def initialize(loop, run_queue, fiber)
      @loop = loop
      @run_queue = run_queue
      @fiber = fiber
      @run_queue.schedule_in @fiber, 0, proc{ @parent_fiber }
    end

    def result(opts = {})
      @parent_fiber = Fiber.current

      if seconds = opts[:within]
        timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
        @timeout = @run_queue.schedule_in @parent_fiber, seconds, timeout_result
      end

      result = @loop.resume

      @parent_fiber = nil

      if seconds
        @timeout.cancel
      end

      (CancelledError === result) ? raise(result) : result
    end

    def cancel(reason = "waiting cancelled")
      @parent_fiber.transfer CancelledError.new(reason)
      :cancelled
    end
  end
end