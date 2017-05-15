class IOEventLoop
  class ConcurrentBlock < Fiber
    def initialize(loop, block_pool)
      # Creation of fibers is quite expensive. To reduce the cost we make
      # concurrent blocks reusable:
      # - Each concurrent block of code is executed during one iteration
      #   of the loop inside the fiber.
      # - At the end of each iteration we put the concurrent block back into
      #   a block pool.
      # - Taking a block out of the pool and resuming it will enter the
      #   next iteration.
      super() do |proc, args, evaluation = []|
        # The fiber's proc, arguments to call the proc with and evaluation
        # are passed when scheduled right after creation or taking it out of
        # the pool.

        while true
          raise Error, "concurrent block started without a proc" unless proc

          result = nil

          if proc == self
            # If we are given this very fiber when starting the concurrent block
            # it means this fiber is evaluated right before its start. In this
            # case just yield back to the evaluating fiber.
            Fiber.yield

            # When this fiber is started because it is next on schedule it will
            # just finish without running the proc.
          else
            begin
              result = proc.call_consecutively *args
              evaluation[0].conclude_with result if evaluation[0]
            rescue CancelledConcurrentBlock
              # Generally, throw-catch is faster than raise-rescue if the code
              # needs to play back the call stack, i.e. the throw resp. raise
              # is invoked. If not playing back the call stack, a begin block
              # is faster than a catch block. Since we mostly won't jump out
              # of proc above, we go with begin-raise-rescue.
            rescue Exception => result
              loop.trigger :error, result
              evaluation[0].conclude_with result if evaluation[0]
            end
          end

          block_pool << self

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