class IOEventLoop
  class ConcurrentProc
    def initialize(fiber, loop, run_queue, data)
      @fiber = fiber
      @loop = loop
      @run_queue = run_queue
      @evaluated = false
      @requesting_fibers = {}
      @data = data.freeze
    end

    attr_reader :data

    def await_result(opts = {}) # &with_result
      if @evaluated
        result = @result
      else
        @loop.await_outer(opts) do |fiber|
          @requesting_fibers.store(fiber, true)
          result = @loop.await_inner(fiber)
          @requesting_fibers.delete fiber
          result
        end
      end

      result = yield result if block_given?

      (Exception === result) ? (raise result) : result
    end

    attr_reader :evaluated
    alias evaluated? evaluated
    undef evaluated

    def evaluate_to(result)
      if @evaluated
        raise self.class::Error, "already evaluated"
      end

      @result = result
      @evaluated = true

      @fiber.cancel

      @requesting_fibers.each_key{ |fiber| @run_queue.schedule(fiber, 0, result) }
      :evaluated
    end

    def cancel(reason = "evaluation cancelled")
      evaluate_to self.class::CancelledError.new(reason)
      :cancelled
    end
  end
end