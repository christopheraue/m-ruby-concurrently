module Concurrently
  # Not to be instantiated directly. A new Evaluation instance will be
  # returned by {Proc#call_nonblock} or {Proc#call_detached}.
  class Proc::Evaluation
    # An error indicating the execution of the concurrent proc's block of code
    # raised an error.
    Error = Proc::Error

    # @api private
    def initialize(proc_fiber)
      @proc_fiber = proc_fiber
      @concluded = false
      @awaiting_result = {}
      @data = {}
    end

    # A hash for custom data to be stored in this instance. Useful if creating
    # a subclass and overwriting {#await_result} or {#conclude_with}
    attr_reader :data

    # Waits for the evaluation to be concluded with a result
    def await_result(opts = {}) # &with_result
      if @concluded
        result = @result
      else
        result = begin
          fiber = Concurrently::EventLoop.current.current_fiber
          @awaiting_result.store fiber, true
          await_scheduled_resume! opts
        rescue Exception => error
          error
        ensure
          @awaiting_result.delete fiber
        end
      end

      result = yield result if block_given?

      (Exception === result) ? (raise result) : result
    end

    # @private
    # will be undefined in a few lines
    attr_reader :concluded

    # Checks if the evaluation is concluded
    alias concluded? concluded
    undef concluded

    # Cancels the evaluation of the concurrent proc prematurely by evaluating
    # it to a result.
    def conclude_with(result)
      if @concluded
        raise self.class::Error, "already concluded"
      end

      @result = result
      @concluded = true

      @proc_fiber.cancel!

      @awaiting_result.each_key{ |fiber| fiber.schedule_resume! result }
      :concluded
    end

    # Cancels the evaluation of the concurrent proc prematurely by evaluating
    # it to a CancelledError.
    def cancel(reason = "evaluation cancelled")
      conclude_with Proc::CancelledError.new(reason)
      :cancelled
    end

    # Schedules the evaluation of the concurrent proc to be resumed
    def schedule_resume!(result = nil)
      @proc_fiber.schedule_resume! result
    end
  end
end