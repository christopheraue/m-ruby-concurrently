class IOEventLoop
  class Concurrency
    class Future
      def initialize(concurrency, run_queue)
        @concurrency = concurrency
        @run_queue = run_queue
      end
  
      def result(opts = {})
        @requesting_fiber = Fiber.current

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
          @timeout = @run_queue.schedule_in @requesting_fiber, seconds, timeout_result
        end

        @concurrency.requesting_fiber = @requesting_fiber

        # yields back to the loop from the current Concurrency
        result = Fiber.yield

        @concurrency.requesting_fiber = nil

        if seconds
          @timeout.cancel
        end

        (CancelledError === result) ? raise(result) : result
      end

      def cancel(reason = "waiting cancelled")
        if @requesting_fiber
          @requesting_fiber.resume CancelledError.new(reason)
        else
          @concurrency.cancel
        end
        :cancelled
      end
    end
  end
end