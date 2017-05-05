class IOEventLoop
  class TimeFuture
    def initialize(loop, run_queue, seconds)
      @loop = loop
      @fiber = Fiber.current
      run_queue.schedule_in @fiber, seconds
    end

    def await
      @loop.io_event_loop.transfer
    end
  end
end