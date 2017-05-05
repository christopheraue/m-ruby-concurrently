class IOEventLoop
  class Concurrency
    class Future
      def initialize(concurrency)
        @concurrency = concurrency
      end
  
      def result(opts = {})
        @requesting_fiber = Fiber.current

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
          Concurrency.current.schedule_in seconds, timeout_result
        end

        @concurrency.requesting_fiber = @requesting_fiber

        # yields back to the loop from the current Concurrency
        result = Fiber.yield

        @concurrency.requesting_fiber = nil

        (CancelledError === result) ? raise(result) : result
      end

      def cancel(reason = "waiting cancelled")
        @requesting_fiber.resume CancelledError.new(reason)
        :cancelled
      end

      def cancel_schedule
        @concurrency.cancel_schedule
      end
    end
  end
end