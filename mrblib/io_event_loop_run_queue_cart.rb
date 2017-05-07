class IOEventLoop
  class RunQueue::Cart
    def initialize(fiber, time, result)
      @fiber = fiber
      @time = time
      @result = result
    end

    attr_reader :time

    def process
      @fiber.transfer @result if @fiber
    end

    def cancel
      @fiber = false
    end

    def active?
      !!@fiber
    end
  end
end