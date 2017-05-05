class IOEventLoop
  class RunQueueEntry
    include Comparable

    def initialize(fiber, time, result)
      @fiber = fiber
      @scheduled = true
      @schedule_time = time
      @schedule_result = result
    end

    attr_reader :fiber

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