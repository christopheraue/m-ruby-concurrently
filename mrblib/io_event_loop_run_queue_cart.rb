class IOEventLoop
  class RunQueue::Cart
    include Comparable

    def initialize(fiber, time, result)
      @fiber = fiber
      @time = time
      @result = result
    end

    attr_reader :time
    alias to_f time

    def process
      @fiber.resume @result if @fiber
    end

    def cancel
      @fiber = false
    end

    def active?
      !!@fiber
    end

    def <=>(other)
      @time <=> other.to_f
    end
  end
end