class IOEventLoop
  class Concurrency
    def initialize(loop, &block)
      @fiber = Fiber.new do
        begin
          block.call
        rescue Exception => e
          loop.trigger :error, e
        end
      end
    end

    attr_reader :fiber

    def resume
      @fiber.resume true
    end

    def await_result
      result = Fiber.yield
      (CancelledError === result) ? raise(result) : result
    end

    def inject_result(result)
      @fiber.resume result
    end
  end
end