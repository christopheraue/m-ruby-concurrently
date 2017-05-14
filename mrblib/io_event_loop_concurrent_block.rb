class IOEventLoop
  class ConcurrentBlock < Fiber
    def initialize(loop, block_pool)
      # Creation of fibers is quite expensive. To reduce the cost we make
      # concurrent blocks reusable:
      # - Each concurrent block of code is executed during one iteration
      #   of the loop inside the fiber.
      # - At the end of each iteration we put the fiber back into a block
      #   pool.
      # - Taking a block out of the pool and resuming it will enter the
      #   next iteration.
      super() do |block, evaluation|
        # The fiber's block and evaluation are passed when scheduled right after
        # creation or taking it out of the pool.

        while true
          raise Error, "concurrent block ran without being started" unless block

          if block == self
            # If we are given this very fiber when starting the fiber for real
            # it means this fiber is evaluated right before its start. In this
            # case just yield back to the cancelling fiber.
            Fiber.yield

            # When this fiber is started when it is the next on schedule it will
            # just finish without running the block.
          else
            begin
              result = block.call_consecutively
              evaluation.conclude_with result if evaluation
            rescue CancelledConcurrentBlock
              # Generally, throw-catch is faster than raise-rescue if the code
              # needs to play back the call stack, i.e. the throw resp. raise
              # is invoked. If not playing back the call stack, a begin block
              # is faster than a catch block. Since we mostly won't jump out
              # of block above, we go with begin-raise-rescue.
            rescue Exception => e
              loop.trigger :error, e
              evaluation.conclude_with e if evaluation
            end
          end

          block_pool << self

          # Yield back to the event loop fiber or the fiber cancelling this one
          # and wait for the next block to evaluate.
          block, evaluation = Fiber.yield
        end
      end
    end

    def cancel
      if Fiber.current != self
        # Cancel fiber by resuming it with itself as argument
        resume self
      end
      :cancelled
    end
  end
end