module Concurrently
  # `Concurrently::Proc::Evaluation` represents the evaluation of a concurrent
  # proc.
  #
  # An instance will be returned by {Evaluation.current} if called from inside
  # a concurrent proc. It will also be returned by every call of
  # {Concurrently::Proc#call_detached} and also by
  # {Concurrently::Proc#call_nonblock} if the evaluation cannot be concluded in
  # one go and needs to wait.
  class Proc::Evaluation < Evaluation
    # @api private
    def initialize(fiber)
      super
      @concluded = false
      @awaiting_result = {}
      @data = {}
    end

    # A hash for custom data. Use it to attach data being specific to
    # evaluations. An example would be giving each evaluation an id.
    #
    # @return [Hash]
    #
    # @example
    #   evaluation = concurrent_proc{ :result }.call_detached
    #   evaluation.data[:id] = :an_id
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

    # @!attribute [r] concluded?
    #
    # Checks if the evaluation is concluded
    #
    # @return [Boolean]
    def concluded?
      @concluded
    end

    # Cancels the evaluation of the concurrent proc prematurely by evaluating
    # it to a result.
    def conclude_to(result)
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
  end
end