module Concurrently
  # @api public
  # @since 1.0.0
  #
  # `Concurrently::Evaluation` represents the evaluation of the main thread
  # outside of any concurrent evaluations.
  #
  # @note Evaluations are **not thread safe**. They are operating on a fiber.
  #   Fibers cannot be resumed inside a thread they were not created in.
  #
  # An instance will be returned by {current} if called by the root evaluation.
  class Evaluation
    # The evaluation that is currently running in the current thread.
    #
    # This method is thread safe. Each thread returns its own currently running
    # evaluation.
    #
    # @return [Evaluation]
    #
    # @example
    #   concurrently do
    #     Concurrently::Evaluation.current # => #<Concurrently::Proc::Evaluation:0x00000000e56910>
    #   end
    #
    #   Concurrently::Evaluation.current # => #<Concurrently::Evaluation:0x00000000e5be10>
    def self.current
      EventLoop.current.run_queue.current_evaluation
    end

    # @private
    def initialize(fiber)
      @fiber = fiber
      @waiting = false
    end

    # @private
    #
    # Suspends the evaluation. This is a method called internally only.
    def __suspend__(event_loop_fiber)
      @waiting = true
      event_loop_fiber.resume
    end

    # @private
    #
    # Resumes the evaluation. This is a method called internally only.
    def __resume__(result)
      @scheduled = false
      Fiber.yield result
    end

    # @!attribute [r] waiting?
    #
    # Checks if the evaluation is not running and not resumed.
    #
    # @return [Boolean]
    def waiting?
      !!@waiting
    end

    # @private
    #
    # Called by {Proc::Evaluation#await_result}. This is a method called
    # internally only.
    def __await_result_of__(evaluation, opts)
      evaluation.__add_waiting_evaluation__ self
      await_resume! opts
    ensure
      evaluation.__remove_waiting_evaluation__ self
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
    # evaluation = concurrent_proc do
    #   wait 1
    #   await_resume!
    # end.call_nonblock
    #
    # conproc.resume! # resumes the wait call prematurely
    # ```
    #
    # To use this method safely, make sure the evaluation to resume is waiting
    # because of a manual call of {Kernel#await_resume!}.
    #
    # @return [:resumed]
    # @raise [Error] if the evaluation is not waiting or is already scheduled
    #   to be resumed
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
    def __resume__!(result = nil)
      raise self.class::Error, "already scheduled\n#{Debug.notice_for @fiber}" if @scheduled
      raise self.class::Error, "not waiting\n#{Debug.notice_for @fiber}" unless @waiting
      @waiting = false
      @scheduled = true

      run_queue = Concurrently::EventLoop.current.run_queue

      # Cancel running the fiber if it has already been scheduled to run; but
      # only if it was scheduled with a time offset. This is used to cancel the
      # timeout of a wait operation if the waiting fiber is resumed before the
      # timeout is triggered.
      run_queue.cancel(self, true)

      run_queue.schedule_immediately(self, result)
      :resumed
    end
    alias resume! __resume__!

    Debug.overwrite(self) do
      def resume!(result = nil)
        Debug.log_schedule @fiber, caller
        __resume__! result
      end
    end
  end
end