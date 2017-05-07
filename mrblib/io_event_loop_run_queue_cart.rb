class IOEventLoop
  class RunQueue::Cart
    def initialize(fiber, time, result)
      @fiber = fiber
      @time = time
      @result = result
      @active = true
    end

    attr_reader :time

    attr_reader :active
    alias active? active
    undef active

    def process
      @fiber.transfer @result if @active
    end

    def cancel
      @active = false
    end
  end
end