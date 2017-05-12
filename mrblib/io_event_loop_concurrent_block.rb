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

      super() do |block, future = nil|
        # The fiber is started right away after creation or taking it out of
        # the pool to inject its future and block. It then directly yields back
        # to wait for its actual start.

        while true
          start_argument = Fiber.yield

          if start_argument == self
            # If we are given with this very fiber when starting the fiber for
            # real it means this fiber is already evaluated right before its
            # start. In this case just yield back to the cancelling fiber.
            Fiber.yield

            # When this fiber is started when it is the next on schedule it will
            # just finish without running the block.
          else
            begin
              result = block.call
              future.evaluate_to result if future
            rescue Exception => e
              loop.trigger :error, e
              future.evaluate_to e if future
            end
          end

          block_pool.push self

          # yield back to the event loop fiber and wait for the next block
          # to run.
          block, future = Fiber.yield
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