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

    def schedule_at(schedule_time, schedule_result = nil)
      @schedule_time = schedule_time
      @scheduled = true
      @schedule_result = schedule_result
      @run_queue.schedule self
    end

    attr_reader :schedule_time
    alias_method :to_f, :schedule_time

    def scheduled_resume
      @fiber.resume @schedule_result if @scheduled
    end

    def cancel_schedule
      @scheduled = false
      @schedule_result = nil
    end

    attr_reader :scheduled
    alias_method :scheduled?, :scheduled

    def <=>(other)
      @schedule_time <=> other.to_f
    end

    attr_writer :wait_id

    def resume_with(result)
      @loop.waiting_concurrencies.delete @wait_id
      @fiber.resume result
    end

    def await_result
      result = Fiber.yield
      (CancelledError === result) ? raise(result) : result
    end
  end
end