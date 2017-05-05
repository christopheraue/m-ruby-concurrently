class IOEventLoop
  class Concurrency
    def initialize(loop, run_queue, &body)
      @loop = loop
      @run_queue = run_queue
      @body = body
    end

    attr_reader :loop

    def fiber
      @fiber ||= Fiber.new do |parent_fiber_getter|
        begin
          result = @body.call

          if parent_fiber = parent_fiber_getter.call
            parent_fiber.transfer result
          else
            @loop.io_event_loop.transfer
          end
        rescue Exception => e
          @loop.trigger :error, e
        end
      end
    end
  end
end