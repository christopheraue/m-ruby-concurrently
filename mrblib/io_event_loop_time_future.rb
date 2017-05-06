class IOEventLoop
  class TimeFuture
    def initialize(loop, run_queue, seconds)
      @loop = loop
      @run_queue = run_queue
      @seconds = seconds
    end

    def await
      unless instance_variable_defined? :@result
        @fiber = Fiber.current
        @run_queue.schedule_in @seconds, @fiber
        @result = @loop.resume
        @fiber = false
      end

      (CancelledError === @result) ? raise(@result) : @result
    end

    def cancel(reason = "waiting cancelled")
      @result = CancelledError.new(reason)
      @fiber.transfer @result if @fiber
    end
  end
end