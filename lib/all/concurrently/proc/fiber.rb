module Concurrently
  # @private
  class Proc::Fiber < ::Fiber
    EMPTY_EVALUATION_BUCKET = [].freeze

    def initialize(fiber_pool)
      # Creation of fibers is quite expensive. To reduce the cost we make
      # them reusable:
      # - Each concurrent proc is executed during one iteration of the loop
      #   inside a fiber.
      # - At the end of each iteration we put the fiber back into the fiber
      #   pool of the event loop.
      # - Taking a fiber out of the pool and resuming it will enter the
      #   next iteration.
      super() do |proc, args, evaluation_bucket|
        # The fiber's proc, arguments to call the proc with and evaluation
        # are passed when scheduled right after creation or taking it out of
        # the pool.

        while true
          evaluation_bucket ||= EMPTY_EVALUATION_BUCKET

          result = if proc.equal? Proc::Evaluation::Cancelled
            # If we are given this very fiber when starting itself it means it
            # has been evaluated right before its start. In this case just
            # yield back to the evaluating fiber.
            Fiber.yield

            # When this fiber is started because it is next on schedule it will
            # just finish without running the proc.

            :cancelled
          elsif not Proc === proc
            raise Concurrently::Error, "Concurrent evaluation not started " <<
              "properly. This should never happen and if it does it means " <<
              "there is a bug in Concurrently."
          else
            begin
              result = proc.__fiber_call__ self, args
              if (evaluation = evaluation_bucket[0]) and not evaluation.concluded?
                evaluation.conclude_to result
              end
              result
            rescue Proc::Evaluation::Cancelled
              # raised in Kernel#await_resume!
              :cancelled
            rescue Proc::Evaluation::RescueableError => error
              # Rescue all errors not critical for other concurrent evaluations
              # and don't let them leak to the loop to keep it up and running.
              proc.trigger :error, error
              if (evaluation = evaluation_bucket[0]) and not evaluation.concluded?
                evaluation.conclude_to error
              end
              error
            end
          end

          fiber_pool.return self

          # Yield back to the event loop fiber or the fiber evaluating this one
          # and wait for the next proc to evaluate.
          proc, args, evaluation_bucket = Proc::Fiber.yield result
        end
      end
    end

    Concurrently::Debug.overwrite(self) do
      def self.yield(*)
        Concurrently::Debug.log_suspend Fiber.current, caller
        super
      ensure
        Concurrently::Debug.log_resume Fiber.current, caller
      end

      def resume(result, stacktrace = caller)
        Concurrently::Debug.log_suspend Fiber.current, stacktrace
        super result
      ensure
        Concurrently::Debug.log_resume Fiber.current, stacktrace
      end
    end
  end
end