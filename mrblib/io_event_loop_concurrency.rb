class IOEventLoop
  class Concurrency
    include Comparable

    def initialize(loop, start_time = loop.wall_clock.now) #&block
      @loop = loop
      @start_time = start_time
      @cancelled = false
      @fiber = Fiber.new do
        begin
          yield
        rescue Exception => e
          loop.trigger :error, e
        end
      end
      @loop.concurrencies[@fiber] = self
    end

    attr_reader :start_time
    alias_method :to_f, :start_time

    def defer(seconds)
      @start_time += seconds
    end

    def <=>(other)
      @start_time <=> other.to_f
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