class IOEventLoop
  class Concurrency
    class Future
      def initialize(concurrency)
        @concurrency = concurrency
      end
  
      def result(opts = {})
        @requesting_concurrency = Concurrency.current

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
          @requesting_concurrency.schedule_in seconds, timeout_result
        end

        @concurrency.requesting_concurrency = @requesting_concurrency

        # yields back to the loop from the current Concurrency
        result = Fiber.yield

        @concurrency.requesting_concurrency = nil

        (CancelledError === result) ? raise(result) : result
      end

      def cancel(reason = "waiting cancelled")
        @requesting_concurrency.resume_with CancelledError.new(reason)
        :cancelled
      end

      def cancel_schedule
        @concurrency.cancel_schedule
      end
    end
  end
end