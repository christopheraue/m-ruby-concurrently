module Concurrently
  # @api public
  # @since 1.0.0
  #
  # `Concurrently::Proc::Evaluation` represents the evaluation of a concurrent
  # proc.
  #
  # @note Evaluations are **not thread safe**. They are operating on a fiber.
  #   Fibers cannot be resumed inside a thread they were not created in.
  #
  # An instance will be returned by {Evaluation.current} if called by code
  # inside a concurrent proc. It will also be returned by every call of
  # {Concurrently::Proc#call_detached} and also by
  # {Concurrently::Proc#call_nonblock} if the evaluation cannot be concluded in
  # one go and needs to wait.
  class Proc::Evaluation < Evaluation
    # @private
    def initialize(fiber)
      super
      @concluded = false
      @awaiting_result = {}
      @data = {}
    end

    # Attaches a value to the evaluation under the given key
    #
    # @param [Object] key The key to store the value under
    # @param [Object] value The value to store
    # @return [value]
    #
    # @example
    #   evaluation = concurrently{ :result }
    #   evaluation[:key] = :value
    #   evaluation[:key]  # => :value
    def []=(key, value)
      @data[key] = value
    end

    # Retrieves the attached value under the given key
    #
    # @param [Object] key The key to look up
    # @return [Object] the stored value
    #
    # @example
    #   evaluation = concurrently{ :result }
    #   evaluation[:key] = :value
    #   evaluation[:key]  # => :value
    def [](key)
      @data[key]
    end

    # Checks if there is an attached value for the given key
    #
    # @param [Object] key The key to look up
    # @return [Boolean]
    #
    # @example
    #   evaluation = concurrently{ :result }
    #   evaluation[:key] = :value
    #   evaluation.key? :key          # => true
    #   evaluation.key? :another_key  # => false
    def key?(key)
      @data.key? key
    end

    # Returns all keys with values
    #
    # @return [Array]
    #
    # @example
    #   evaluation = concurrently{ :result }
    #   evaluation[:key1] = :value1
    #   evaluation[:key2] = :value2
    #   evaluation.keys  # => [:key1, :key2]
    def keys
      @data.keys
    end

    # @private
    #
    # Suspends the evaluation. This is a method called internally only.
    def __suspend__(event_loop_fiber)
      @waiting = true
      # Yield back to the event loop fiber or the evaluation evaluating this one.
      # Pass along itself to indicate it is not yet fully evaluated.
      Proc::Fiber.yield self
    ensure
      @waiting = false
    end

    # @private
    #
    # Resumes the evaluation. This is a method called internally only.
    def __resume__(result)
      @scheduled = false
      @fiber.resume result
    end

    Concurrently::Debug.overwrite(self) do
      def __resume__(result)
        @scheduled = false
        @fiber.resume result, @scheduled_caller
      end
    end

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
    # @example Waiting inside another concurrent evaluation
    #   # Control flow is indicated by (N)
    #
    #   # (1)
    #   evaluation = concurrently do
    #     # (4)
    #     :result
    #   end
    #
    #   # (2)
    #   concurrent_proc do
    #     # (3)
    #     evaluation.await_result
    #     # (5)
    #   end.call # => :result
    #   # (6)
    #
    # @example Waiting outside a concurrent evaluation
    #   # Control flow is indicated by (N)
    #
    #   # (1)
    #   evaluation = concurrently do
    #     # (3)
    #     :result
    #   end
    #
    #   # (2)
    #   evaluation.await_result # => :result
    #   # (4)
    #
    # @example Waiting with a timeout
    #   evaluation = concurrently do
    #     wait 1
    #     :result
    #   end
    #
    #   evaluation.await_result within: 0.1
    #   # => raises a TimeoutError after 0.1 seconds
    #
    # @example Waiting with a timeout and a timeout result
    #   evaluation = concurrently do
    #     wait 1
    #     :result
    #   end
    #
    #   evaluation.await_result within: 0.1, timeout_result: false
    #   # => returns false after 0.1 seconds
    #
    # @example When the evaluation raises or returns an error
    #   evaluation = concurrently do
    #     RuntimeError.new("self destruct!") # equivalent: raise "self destruct!"
    #   end
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
    #     evaluation = concurrently do
    #       :result
    #     end
    #
    #     evaluation.await_result{ |result| "transformed_#{result}" }
    #     # => "transformed_result"
    #
    #   @example Validating a result
    #     evaluation = concurrently do
    #       :invalid_result
    #     end
    #
    #     evaluation.await_result{ |result| raise "invalid result" if result != :result }
    #     # => raises "invalid result"
    def await_result(opts = {}) # &with_result
      if @concluded
        result = @result
      else
        result = begin
          evaluation = Concurrently::Evaluation.current
          @awaiting_result.store evaluation, false
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

    # Cancels the concurrent evaluation prematurely by injecting a result.
    #
    # @param [Object] result
    #
    # @return [:concluded]
    # @raise [Error] if it is already concluded
    #
    # @example
    #   # Control flow is indicated by (N)
    #
    #   # (1)
    #   evaluation = concurrently do
    #     # (4)
    #     wait 1
    #     # never reached
    #     :result
    #   end
    #
    #   # (2)
    #   concurrently do
    #     # (5)
    #     evaluation.conclude_to :premature_result
    #   end
    #
    #   # (3)
    #   evaluation.await_result # => :premature_result
    #   # (6)
    def conclude_to(result)
      if @concluded
        raise self.class::Error, "already concluded"
      end

      @result = result
      @concluded = true

      if Fiber.current != @fiber
        # Cancel its fiber
        run_queue = Concurrently::EventLoop.current.run_queue
        previous_evaluation = run_queue.current_evaluation
        run_queue.current_evaluation = self
        @fiber.resume Cancelled
        run_queue.current_evaluation = previous_evaluation
      end

      @awaiting_result.each{ |evaluation, override| evaluation.resume! (override or result) }
      :concluded
    end

    # Schedules the evaluation to be resumed
    #
    # For details see: {Concurrently::Evaluation#resume!}
    #
    # @raise [Evaluation::Error] if the evaluation is already concluded
    def resume!(*)
      raise self.class::Error, "already concluded" if @concluded
      super
    end
  end
end