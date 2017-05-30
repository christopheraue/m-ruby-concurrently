module Concurrently
  # @api private
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
            raise Proc::Error, "Concurrently::Proc::Evaluation#resume! called " <<
              "without an earlier call to Kernel#await_resume!"
          else
            begin
              result = proc.__proc_call__ *args
              (evaluation = evaluation_bucket[0]) and evaluation.conclude_with result
              result
            rescue Cancelled
              # raised in Kernel#await_resume!
              :cancelled
            rescue Exception => error
              # Rescue all exceptions and let none leak to the loop to keep it
              # up and running at all times.
              proc.trigger :error, error
              (evaluation = evaluation_bucket[0]) and evaluation.conclude_with error
              error
            end
          end

          fiber_pool << self

          # Yield back to the event loop fiber or the fiber evaluating this one
          # and wait for the next proc to evaluate.
          proc, args, evaluation_bucket = Fiber.yield result
        end
      end
    end
  end
end