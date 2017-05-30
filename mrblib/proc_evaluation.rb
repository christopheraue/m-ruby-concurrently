module Concurrently
  # Not to be instantiated directly. A new Evaluation instance will be
  # returned by {Proc#call} or one of its variants.
  class Proc::Evaluation < Evaluation
    # An error indicating the execution of the concurrent proc's block of code
    # raised an error.
    Error = Proc::Error

    # @api private
    def initialize(fiber)
      super
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
          evaluation = Concurrently::Evaluation.current
          @awaiting_result.store evaluation, true
          await_resume! opts
        rescue Exception => error
          error
        ensure
          @awaiting_result.delete evaluation
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

      if Fiber.current != @fiber
        # Cancel fiber by resuming it with itself as argument
        @fiber.resume @fiber
      end

      @awaiting_result.each_key{ |evaluation| evaluation.resume! result }
      :concluded
    end

    # Cancels the evaluation of the concurrent proc prematurely by evaluating
    # it to a CancelledError.
    def cancel(reason = "evaluation cancelled")
      conclude_with Proc::CancelledError.new(reason)
      :cancelled
    end
  end
end