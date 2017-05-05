class IOEventLoop
  class Concurrency
    class Future
      def initialize(concurrency, run_queue)
        @concurrency = concurrency
        @run_queue = run_queue
      end
  
      def result(opts = {})
        @fiber = Fiber.current

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
          @timeout = @run_queue.schedule_in @fiber, seconds, timeout_result
        end

        @concurrency.requesting_fiber = @fiber

        # yields back to the loop from the current Concurrency
        result = @concurrency.loop.io_event_loop.transfer

        @concurrency.requesting_fiber = nil

        if seconds
          @timeout.cancel
        end

        (CancelledError === result) ? raise(result) : result
      end

      def cancel(reason = "waiting cancelled")
        @fiber.transfer CancelledError.new(reason)
        :cancelled
      end
    end
  end
end