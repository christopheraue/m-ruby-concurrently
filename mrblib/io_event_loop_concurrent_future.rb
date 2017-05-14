class IOEventLoop
  class ConcurrentFuture
    def initialize(concurrent_block, loop, data)
      @concurrent_block = concurrent_block
      @loop = loop
      @evaluated = false
      @awaiting_result = {}
      @data = data.freeze
    end

    attr_reader :data

    def await_result(opts = {}) # &with_result
      if @evaluated
        result = @result
      else
        result = begin
          fiber = Fiber.current
          @awaiting_result.store fiber, true
          @loop.await_outer do
            @loop.await_inner(fiber, opts)
          end
        ensure
          @awaiting_result.delete fiber
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

      @concurrent_block.cancel

      @awaiting_result.each_key{ |fiber| @loop.inject_result(fiber, result) }
      :evaluated
    end

    def cancel(reason = "evaluation cancelled")
      evaluate_to self.class::CancelledError.new(reason)
      :cancelled
    end
  end
end