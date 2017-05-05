class IOEventLoop
  class Concurrency
    def initialize(loop, run_queue, opts = {}, &body)
      @loop = loop
      @run_queue = run_queue
      @interval = opts.fetch(:every, false)
      @body = body
    end

    attr_reader :loop

    attr_writer :requesting_fiber

    def fiber
      @fiber ||= Fiber.new do
        begin
          while true
            result = @body.call

            if @interval
              @run_queue_entry = @run_queue.schedule @fiber, @run_queue_entry.schedule_time+@interval if @run_queue_entry.scheduled?
              Fiber.yield # go back to the main loop
            else
              cancel_schedule
              @requesting_fiber.resume result if @requesting_fiber
              break
            end
          end
        rescue Exception => e
          @loop.trigger :error, e
        end
      end
    end

    def schedule_in(seconds, result = nil)
      @run_queue_entry = @run_queue.schedule_in fiber, seconds, result
    end

    def cancel_schedule
      @run_queue_entry.cancel_schedule if @run_queue_entry
    end
  end
end