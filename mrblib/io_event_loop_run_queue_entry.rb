class IOEventLoop
  class RunQueueEntry
    include Comparable

    def initialize(fiber)
      @fiber = fiber
    end

    attr_reader :fiber

    attr_reader :schedule_time
    alias to_f schedule_time

    def schedule(time, result)
      @scheduled = true
      @schedule_time = time
      @schedule_result = result
    end

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