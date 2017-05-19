module Concurrently
  class Proc::Evaluation
    Error = Proc::Error

    def initialize(proc_fiber)
      @proc_fiber = proc_fiber
      @concluded = false
      @awaiting_result = {}
      @data = {}
    end

    attr_reader :data

    def await_result(opts = {}) # &with_result
      if @concluded
        result = @result
      else
        result = begin
          fiber = Fiber.current
          @awaiting_result.store fiber, true
          await_manual_resume! opts
        rescue Exception => error
          error
        ensure
          @awaiting_result.delete fiber
        end
      end

      result = yield result if block_given?

      (Exception === result) ? (raise result) : result
    end

    attr_reader :concluded
    alias concluded? concluded
    undef concluded

    def conclude_with(result)
      if @concluded
        raise self.class::Error, "already concluded"
      end

      @result = result
      @concluded = true

      @proc_fiber.cancel!

      @awaiting_result.each_key{ |fiber| fiber.manually_resume! result }
      :concluded
    end

    def cancel(reason = "evaluation cancelled")
      conclude_with Proc::CancelledError.new(reason)
      :cancelled
    end

    def manually_resume!(result = nil)
      @proc_fiber.manually_resume! result
    end
  end
end