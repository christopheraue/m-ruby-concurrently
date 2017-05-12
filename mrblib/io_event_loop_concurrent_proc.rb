class IOEventLoop
  class ConcurrentProc
    def initialize(fiber, loop, data)
      @fiber = fiber
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
        @loop.await_outer(opts) do |fiber|
          @awaiting_result.store fiber, true
          result = @loop.await_inner(fiber)
          @awaiting_result.delete fiber
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

      @awaiting_result.each_key{ |fiber| @loop.inject_result(fiber, result) }
      :evaluated
    end

    def cancel(reason = "evaluation cancelled")
      evaluate_to self.class::CancelledError.new(reason)
      :cancelled
    end
  end
end