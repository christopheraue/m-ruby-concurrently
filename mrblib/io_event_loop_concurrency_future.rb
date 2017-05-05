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
          @timeout = Concurrency.current.schedule_in seconds, timeout_result
        end

        @concurrency.requesting_fiber = @requesting_fiber

        # yields back to the loop from the current Concurrency
        result = Fiber.yield

        @concurrency.requesting_fiber = nil

        if seconds
          @timeout.cancel_schedule
        end

        (CancelledError === result) ? raise(result) : result
      end

      def cancel(reason = "waiting cancelled")
        if @requesting_fiber
          @requesting_fiber.resume CancelledError.new(reason)
        else
          @concurrency.cancel_schedule
        end
        :cancelled
      end
    end
  end
end