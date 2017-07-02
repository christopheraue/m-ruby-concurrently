module Concurrently
  # @private
  class Proc::Fiber < ::Fiber
    class Cancelled < Exception
      # should not be rescued accidentally and therefore is an exception
    end

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

          result = if proc == self
            # If we are given this very fiber when starting itself it means it
            # has been evaluated right before its start. In this case just
            # yield back to the evaluating fiber.
            Fiber.yield

            # When this fiber is started because it is next on schedule it will
            # just finish without running the proc.

            :cancelled
          elsif not Proc === proc
            # This should never happen. If it does it means something with code
            # of this library is not right.
            raise Concurrently::Error, "concurrent proc not started properly."
          else
            begin
              result = proc.__proc_call__ *args
              (evaluation = evaluation_bucket[0]) and evaluation.conclude_to result
              result
            rescue Cancelled
              # raised in Kernel#await_resume!
              :cancelled
            rescue *RESCUABLE_ERRORS => error
              # Rescue all errors not critical for other concurrent evaluations
              # and don't let them leak to the loop to keep it up and running.
              STDERR.puts error
              proc.trigger :error, error
              (evaluation = evaluation_bucket[0]) and evaluation.conclude_to error
              error
            end
          end

          fiber_pool.return self

          # Yield back to the event loop fiber or the fiber evaluating this one
          # and wait for the next proc to evaluate.
          proc, args, evaluation_bucket = Fiber.yield result
        end
      end
    end
  end
end