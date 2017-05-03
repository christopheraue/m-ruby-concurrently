class IOEventLoop
  class Concurrency
    include Comparable

    def initialize(loop, opts = {}) #&block
      @loop = loop
      @fiber = Fiber.new do
        begin
          yield
        rescue Exception => e
          loop.trigger :error, e
        end
      end
      @resume_time = WallClock.now + opts.fetch(:after, 0)
      @cancelled = false
      @loop.concurrencies[@fiber] = self
      @loop.run_queue.schedule self
    end

    attr_reader :resume_time
    alias_method :to_f, :resume_time

    def resume_with(result)
      @fiber.resume result unless @cancelled
      :resumed
    end

    def await_result
      result = Fiber.yield
      (CancelledError === result) ? raise(result) : result
    end

    def defer(seconds)
      @resume_time += seconds
      @loop.run_queue.schedule self
    end

    def cancel
      @cancelled = true
    end

    def cancelled?
      @cancelled
    end

    def <=>(other)
      @resume_time <=> other.to_f
    end
  end
end