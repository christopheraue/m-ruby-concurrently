class IOEventLoop
  class Concurrency
    REGISTRY = {}

    class << self
      def current
        REGISTRY[Fiber.current]
      end
    end

    include Comparable

    def initialize(loop, run_queue, opts = {}, &body)
      @loop = loop
      @run_queue = run_queue
      @interval = opts.fetch(:every, false)
      @body = body
      schedule_in opts.fetch(:after, 0)
    end

    attr_reader :loop

    attr_writer :requesting_concurrency

    private def fiber
      @fiber ||= Fiber.new do
        begin
          REGISTRY[@fiber] = self

          while true
            result = @body.call

            if @interval
              schedule_at @schedule_time+@interval if @scheduled
              Fiber.yield # go back to the main loop
            else
              @requesting_concurrency.resume_with result if @requesting_concurrency
              break
            end
          end
        rescue Exception => e
          @loop.trigger :error, e
        ensure
          REGISTRY.delete @fiber
        end
      end
    end

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

    def resume_with(result)
      cancel_schedule
      fiber.resume result
    end
  end
end