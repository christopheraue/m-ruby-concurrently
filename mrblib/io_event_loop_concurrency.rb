class IOEventLoop
  class RunQueueEntry; end

  class Concurrency < RunQueueEntry
    REGISTRY = {}

    class << self
      def current
        REGISTRY[Fiber.current]
      end
    end

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
          REGISTRY[@fiber] = self

          while true

            result = @body.call

            if @interval
              @run_queue.schedule self, @schedule_time+@interval if @scheduled
              Fiber.yield # go back to the main loop
            else
              cancel_schedule
              @requesting_fiber.resume result if @requesting_fiber
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

    def schedule_in(seconds, result = nil)
      @run_queue.schedule self, @loop.wall_clock.now+seconds, result
    end
  end
end