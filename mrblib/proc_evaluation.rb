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

    # Waits for the evaluation to be concluded with a result.
    #
    # The result can be awaited from multiple places at once. All of them are
    # resumed once the result is available.
    #
    # @param [Hash] opts
    # @option opts [Numeric] :within maximum time to wait *(defaults to: Float::INFINITY)*
    # @option opts [Object] :timeout_result result to return in case of an exceeded
    #   waiting time *(defaults to raising {Concurrently::Evaluation::TimeoutError})*
    #
    # @return [Object] the result the evaluation is concluded with
    # @raise [Exception] if the result is an exception.
    # @raise [Concurrently::Evaluation::TimeoutError] if a given maximum waiting time
    #   is exceeded and no custom timeout result is given.
    #
    # @example Waiting inside another concurrent proc
    #   # Control flow is indicated by (N)
    #
    #   # (1)
    #   evaluation = concurrent_proc do
    #     # (4)
    #     :result
    #   end.call_detached
    #
    #   # (2)
    #   concurrent_proc do
    #     # (3)
    #     evaluation.await_result
    #     # (5)
    #   end.call # => :result
    #   # (6)
    #
    # @example Waiting outside a concurrent proc
    #   # Control flow is indicated by (N)
    #
    #   # (1)
    #   evaluation = concurrent_proc do
    #      # (3)
    #     :result
    #   end.call_detached
    #
    #   # (2)
    #   evaluation.await_result # => :result
    #   # (4)
    #
    # @example Waiting with a timeout
    #   evaluation = concurrent_proc do
    #     wait 1
    #     :result
    #   end.call_detached
    #
    #   evaluation.await_result within: 0.1
    #   # => raises a TimeoutError after 0.1 second
    #
    # @example Waiting with a timeout and a timeout result
    #   evaluation = concurrent_proc do
    #     wait 1
    #     :result
    #   end.call_detached
    #
    #   evaluation.await_result within: 0.1, timeout_result: false
    #   # => returns false after 0.1 second
    #
    # @example When the evaluation raises or returns an error
    #   evaluation = concurrent_proc do
    #     RuntimeError.new("self destruct!") # equivalent: raise "self destruct!"
    #   end.call_detached
    #
    #   evaluation.await_result # => raises "self destruct!"
    #
    # @overload await_result(opts = {})
    #
    # @overload await_result(opts = {})
    #   Use the block to do something with the result before returning it. This
    #   can be used to validate or transform the result.
    #
    #   @yieldparam result [Object] its result
    #   @yieldreturn [Object] a (potentially) transformed result
    #
    #   @example Transforming a result
    #     evaluation = concurrent_proc do
    #       :result
    #     end.call_detached
    #
    #     evaluation.await_result{ |result| "transformed_#{result}" }
    #     # => "transformed_result"
    #
    #   @example Validating a result
    #     evaluation = concurrent_proc do
    #       :invalid_result
    #     end.call_detached
    #
    #     evaluation.await_result{ |result| raise "invalid result" if result != :result }
    #     # => raises "invalid result"
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