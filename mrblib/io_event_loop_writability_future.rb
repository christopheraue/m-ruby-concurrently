class IOEventLoop
  class WritabilityFuture
    def initialize(loop, run_queue, io)
      @loop = loop
      @run_queue = run_queue
      @io = io
    end

    def await(opts = {})
      unless instance_variable_defined? :@result
        @fiber = Fiber.current

        if seconds = opts[:within]
          timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
          timeout = @run_queue.schedule_in seconds, @fiber, timeout_result
        end

        @loop.attach_writer(@io) { @loop.detach_writer(@io); @fiber.transfer }
        @result = @loop.resume

        if seconds
          timeout.cancel
        end

        @fiber = false
      end

      (CancelledError === @result) ? raise(@result) : @result
    end

    def cancel(reason = "waiting cancelled")
      @loop.detach_writer @io
      @result = CancelledError.new(reason)
      @fiber.transfer @result if @fiber
    end
  end
end