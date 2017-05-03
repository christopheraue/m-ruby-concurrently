class IOEventLoop
  class Concurrency
    include Comparable

    def initialize(loop, after = 0) #&block
      @loop = loop
      @cancelled = false
      @fiber = Fiber.new do
        begin
          yield
        rescue Exception => e
          loop.trigger :error, e
        end
      end
      @resume_time = @loop.wall_clock.now + after
      @loop.concurrencies[@fiber] = self
    end

    attr_reader :resume_time
    alias_method :to_f, :resume_time

    def defer(seconds)
      @resume_time += seconds
    end

    def <=>(other)
      @resume_time <=> other.to_f
    end

    def start
      @fiber.resume unless @cancelled
    end

    def cancel
      @cancelled = true
    end

    def cancelled?
      @cancelled
    end

    def resume_with(result)
      @fiber.resume result
    end

    def await_result
      result = Fiber.yield
      (CancelledError === result) ? raise(result) : result
    end
  end
end