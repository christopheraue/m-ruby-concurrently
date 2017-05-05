class IOEventLoop
  class RunQueueEntry
    include Comparable

    def initialize(fiber)
      @fiber = fiber
    end

    attr_reader :fiber

    def schedule_at(schedule_time, schedule_result = nil)
      @schedule_time = schedule_time
      @scheduled = true
      @schedule_result = schedule_result
      @run_queue.schedule self
    end

    def schedule_in(seconds, schedule_result = nil)
      schedule_at @loop.wall_clock.now+seconds, schedule_result
    end

    attr_reader :schedule_time
    alias to_f schedule_time

    def scheduled_resume
      fiber.resume @schedule_result if @scheduled
    end

    def cancel_schedule
      @scheduled = false
      @schedule_result = nil
    end

    attr_reader :scheduled
    alias scheduled? scheduled
    undef scheduled

    def <=>(other)
      @schedule_time <=> other.to_f
    end
  end
end