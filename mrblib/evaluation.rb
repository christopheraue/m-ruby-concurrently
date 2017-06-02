module Concurrently
  # `Concurrently::Evaluation` represents the evaluation of the main thread
  # outside of any concurrent procs.
  #
  # @note Evaluations are **not thread safe**. They are operating on a fiber.
  #   Fibers cannot be resumed inside a thread they were not created in.
  #
  # An instance will be returned by {current} if called outside of any
  # concurrent procs.
  class Evaluation
    # The evaluation that is currently running in the current thread.
    #
    # This method is thread safe. Each thread returns its own currently running
    # evaluation.
    #
    # @return [Evaluation]
    #
    # @example
    #   concurrent_proc do
    #     Concurrently::Evaluation.current # => #<Concurrently::Proc::Evaluation:0x00000000e56910>
    #   end.call_nonblock
    #
    #   Concurrently::Evaluation.current # => #<Concurrently::Evaluation0x00000000e5be10>
    def self.current
      EventLoop.current.run_queue.current_evaluation
    end

    # @api private
    def initialize(fiber)
      @fiber = fiber
    end

    # The fiber the evaluation runs inside.
    #
    # @api private
    attr_reader :fiber

    # @!attribute [r] waiting?
    #
    # Checks if the evaluation is waiting
    #
    # @return [Boolean]
    def waiting?
      @waiting
    end

    # @api private
    DEFAULT_RESUME_OPTS = { deferred_only: true }.freeze
    
    # @note The exclamation mark in its name stands for: Watch out!
    #   This method needs to be complemented by an earlier call to
    #   {Kernel#await_resume!}.
    #
    # Schedules the evaluation to be resumed
    #
    # It needs to be complemented by an earlier call to {Kernel#await_resume!}.
    #
    # @return [:resumed]
    # @raise [Error] if the evaluation is not waiting
    #
    # @example
    #   # Control flow is indicated by (N)
    #
    #   # (1)
    #   evaluation = concurrent_proc do
    #     # (2)
    #     await_resume!
    #     # (4)
    #   end.call_nonblock
    #
    #   # (3)
    #   evaluation.resume! :result
    #   # (5)
    #   evaluation.await_result # => :result
    def resume!(result = nil)
      raise Error, "evaluation is not waiting due to an earlier call of Kernel#await_resume!" unless @waiting

      run_queue = Concurrently::EventLoop.current.run_queue

      # Cancel running the fiber if it has already been scheduled to run; but
      # only if it was scheduled with a time offset. This is used to cancel the
      # timeout of a wait operation if the waiting fiber is resume before the
      # timeout is triggered.
      run_queue.cancel(self, DEFAULT_RESUME_OPTS)

      run_queue.schedule_immediately(self, result)
      :resumed
    end
  end
end