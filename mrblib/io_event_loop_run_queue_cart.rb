class IOEventLoop
  class RunQueue::Cart
    def initialize(pool, index)
      @pool = pool
      @index = index
    end

    def load(fiber, time, result, transfer)
      @index[fiber] = self
      @fiber = fiber
      @time = time
      @result = result
      @transfer = transfer
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
      if @loaded
        @loaded = false
        @index.delete @fiber
        @pool.push self

        if @transfer == :transfer
          @fiber.transfer @result
        else
          @fiber.resume @result
        end
      end
    end
  end
end