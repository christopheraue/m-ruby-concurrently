module Concurrently
  # @api public
  # @since 1.0.0
  #
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

    # @private
    def initialize(fiber)
      @fiber = fiber
    end

    # @private
    #
    # The fiber the evaluation runs inside.
    attr_reader :fiber

    # @!attribute [r] waiting?
    #
    # Checks if the evaluation is waiting
    #
    # @return [Boolean]
    def waiting?
      @waiting
    end
    
    # @note The exclamation mark in its name stands for: Watch out!
    #   This method is potentially dangerous and can break stuff. It also
    #   needs to be complemented by an earlier call of {Kernel#await_resume!}.
    #
    # Schedules the evaluation to be resumed
    #
    # It needs to be complemented by an earlier call of {Kernel#await_resume!}.
    #
    # This method is potentially dangerous. {Kernel#wait}, {IO#await_readable},
    # {IO#await_writable} and {Proc::Evaluation#await_result} are implemented
    # with {Kernel#await_resume!}. Concurrent evaluations waiting because of
    # them are resumed when calling {#resume!} although the event they are
    # actually awaiting has not happened yet:
    #
    # ```ruby
    # conproc = concurrent_proc do
    #   wait 1
    #   await_resume!
    # end
    #
    # conproc.resume! # resumes the wait call prematurely
    # ```
    #
    # To use this method safely, make sure the evaluation to resume is waiting
    # because of a manual call of {Kernel#await_resume!}.
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
      run_queue = Concurrently::EventLoop.current.run_queue

      # Cancel running the fiber if it has already been scheduled to run; but
      # only if it was scheduled with a time offset. This is used to cancel the
      # timeout of a wait operation if the waiting fiber is resumed before the
      # timeout is triggered.
      run_queue.cancel(self, true)

      run_queue.schedule_immediately(self, result)
      :resumed
    end
  end
end