class IOEventLoop
  class RunQueue::Cart
    def initialize(pool, index)
      @pool = pool
      @index = index
    end

    def load(fiber, time, result)
      @index.store fiber.hash, self
      @fiber = fiber
      @time = time
      @result = result
      @loaded = true
    end

    attr_reader :fiber, :time, :result

    attr_reader :loaded
    alias loaded? loaded
    undef loaded

    def unload
      @loaded = false
    end

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