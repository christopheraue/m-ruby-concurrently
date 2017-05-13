class IOEventLoop
  class RunQueue::Cart
    def initialize(pool, index)
      @pool = pool
      @index = index
    end

    attr_accessor :fiber, :time, :result, :loaded

    alias loaded? loaded
    undef loaded

    def unload_and_process
      @pool.push @index.delete @fiber.hash

      if @loaded
        @loaded = false

        if ConcurrentBlock === @fiber
          @fiber.resume @result
        else
          Fiber.yield @result # leave event loop and yield to root fiber
        end
      end
    end
  end
end