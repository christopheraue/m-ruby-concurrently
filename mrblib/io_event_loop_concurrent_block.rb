class IOEventLoop
  class ConcurrentBlock
    class Fiber < ::Fiber; end

    def initialize(loop, block_pool, run_queue)
      @loop = loop
      @block_pool = block_pool
      @run_queue = run_queue

      # Creation of fibers is quite expensive. To reduce the cost we make
      # concurrent blocks reusable:
      # - Each concurrent block of code is executed during one iteration
      #   of the loop inside the fiber.
      # - At the end of each iteration we put the fiber back into a block
      #   pool.
      # - Taking a block out of the pool and resuming it will enter the
      #   next iteration.
      @fiber = Fiber.new do |start_arg|
        # The fiber's block and future are passed when scheduled right after
        # creation or taking it out of the pool.

        while true
          if start_arg == @fiber
            # If we are given with this very fiber when starting the fiber for
            # real it means this fiber is already evaluated right before its
            # start. In this case just yield back to the cancelling fiber.
            Fiber.yield

            # When this fiber is started when it is the next on schedule it will
            # just finish without running the block.
          else
            begin
              result = @block.call
              @future.evaluate_to result if @future
            rescue Exception => e
              @loop.trigger :error, e
              @future.evaluate_to e if @future
            end
          end

          @block = nil
          @block_pool << self

          # yield back to the event loop fiber and wait for the next block
          # to run.
          start_arg = Fiber.yield
        end
      end
    end
    
    def start(block, future = nil)
      if @block
        raise Error, 'already running'
      else
        @block = block
        @future = future
        @run_queue.schedule_now @fiber
      end
    end

    def cancel
      if Fiber.current != @fiber
        # Cancel fiber by resuming it with itself as argument
        @fiber.resume @fiber
      end
      :cancelled
    end
  end
end