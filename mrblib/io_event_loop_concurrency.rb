class IOEventLoop
  class Concurrency
    def initialize(loop, run_queue, &body)
      @loop = loop
      @run_queue = run_queue
      @body = body
    end

    attr_reader :loop

    attr_writer :requesting_fiber

    def fiber
      @fiber ||= Fiber.new do
        begin
          result = @body.call

          @run_queue_cart.cancel if @run_queue_cart

          if @requesting_fiber
            @requesting_fiber.transfer result
          else
            @loop.io_event_loop.transfer
          end
        rescue Exception => e
          @loop.trigger :error, e
        end
      end
    end

    def schedule_in(seconds, result = nil)
      @run_queue_cart = @run_queue.schedule_in fiber, seconds, result
    end
  end
end