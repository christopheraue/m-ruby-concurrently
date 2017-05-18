module Concurrently
  class Proc::Fiber < ::Fiber
    # should not be rescued accidentally and therefore is an exception
    class Cancelled < Exception; end

    def initialize(fiber_pool)
      # Creation of fibers is quite expensive. To reduce the cost we make
      # them reusable:
      # - Each concurrent proc is executed during one iteration of the loop
      #   inside a fiber.
      # - At the end of each iteration we put the fiber back into the fiber
      #   pool of the event loop.
      # - Taking a fiber out of the pool and resuming it will enter the
      #   next iteration.
      super() do |proc, args, evaluation|
        # The fiber's proc, arguments to call the proc with and evaluation
        # are passed when scheduled right after creation or taking it out of
        # the pool.

        empty_evaluation_holder = [].freeze

        while true
          evaluation ||= empty_evaluation_holder

          result = nil

          if proc == self
            # If we are given this very fiber when starting itself it means it
            # has been evaluated right before its start. In this case just
            # yield back to the evaluating fiber.
            Fiber.yield

            # When this fiber is started because it is next on schedule it will
            # just finish without running the proc.
            fiber_pool << self
          elsif not Proc === proc
            raise Error, "fiber of concurrent proc started with an invalid proc"
          else
            begin
              result = proc.__proc_call__ *args
              evaluation[0].conclude_with result if evaluation[0]
            rescue Cancelled
              # Generally, throw-catch is faster than raise-rescue if the code
              # needs to play back the call stack, i.e. the throw resp. raise
              # is invoked. If not playing back the call stack, a begin block
              # is faster than a catch block. Since we won't jump out of the
              # proc above most of the time, we go with begin-raise-rescue.
            rescue => result
              evaluation[0] ? (evaluation[0].conclude_with result) : (raise result)
            end
          end

          fiber_pool << self

          # Yield back to the event loop fiber or the fiber evaluating this one
          # and wait for the next proc to evaluate.
          proc, args, evaluation = Fiber.yield result
        end
      end
    end

    def cancel!
      if Fiber.current != self
        # Cancel fiber by resuming it with itself as argument
        resume self
      end
      :cancelled
    end

    def send_to_background!(event_loop)
      # Yield back to the event loop fiber or the fiber evaluating this one.
      # Pass along itself to indicate it is not yet fully evaluated.
      Fiber.yield self
    end

    alias_method :send_to_foreground!, :resume
  end
end