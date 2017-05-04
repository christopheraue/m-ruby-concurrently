class IOEventLoop
  class Concurrency
    include Comparable

    def initialize(loop, run_queue) #&block
      @loop = loop
      @run_queue = run_queue
      @fiber = Fiber.new do
        begin
          yield
        rescue Exception => e
          loop.trigger :error, e
        end
      end
      @loop.concurrencies[@fiber] = self
    end

    def schedule_at(schedule_time)
      @schedule_time = schedule_time
      @scheduled = true
      @run_queue.schedule self
    end

    attr_reader :schedule_time
    alias_method :to_f, :schedule_time

    def scheduled_resume
      @fiber.resume if @scheduled
    end

    def cancel_schedule
      @scheduled = false
    end

    attr_reader :scheduled
    alias_method :scheduled?, :scheduled

    def <=>(other)
      @schedule_time <=> other.to_f
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