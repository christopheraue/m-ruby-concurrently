class IOEventLoop
  class Concurrency
    def initialize(loop, &block)
      @loop = loop
      @fiber = Fiber.new do
        begin
          block.call
        rescue Exception => e
          loop.trigger :error, e
        end
      end
      @loop.concurrencies[@fiber] = self
      @loop.run_queue.push @fiber
    end

    def resume_with(result)
      @loop.run_queue.push [@fiber, result]
      :resumed
    end

    def await_result
      result = Fiber.yield
      (CancelledError === result) ? raise(result) : result
    end
  end
end