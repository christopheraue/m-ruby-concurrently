class IOEventLoop
  class Concurrency
    include Comparable

    def initialize(loop, run_queue) #&block
      @loop = loop
      @run_queue = run_queue
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

    attr_reader :schedule_time
    alias_method :to_f, :schedule_time

    def <=>(other)
      @schedule_time <=> other.to_f
    end

    def schedule_at(schedule_time)
      @schedule_time = schedule_time
      @run_queue.schedule self
    end

    def scheduled_resume
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