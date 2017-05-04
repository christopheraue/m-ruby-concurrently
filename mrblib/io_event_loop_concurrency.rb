class IOEventLoop
  class Concurrency
    include Comparable

    def initialize(loop, run_queue, opts = {}) #&block
      @loop = loop
      @run_queue = run_queue

      schedule_in opts.fetch(:after, 0)
      interval = opts.fetch(:every, false)

      @fiber = Fiber.new do
        begin
          while true
            schedule_at schedule_time+interval if interval
            yield
            Fiber.yield # go back to the main loop
            break unless interval
          end
        rescue Exception => e
          loop.trigger :error, e
        end
      end
    end

    attr_reader :loop

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
      @fiber.resume @schedule_result if @scheduled
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

    def resume_with(result)
      @waiting = false
      cancel_schedule
      @fiber.resume result
    end

    attr_accessor :waiting
  end
end