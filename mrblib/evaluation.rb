module Concurrently
  # Not to be instantiated directly.
  class Evaluation
    # The evaluation that is currently running.
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

    # @api private
    DEFAULT_RESUME_OPTS = { deferred_only: true }.freeze
    
    # Schedules the evaluation to be resumed
    def resume!(result = nil)
      run_queue = Concurrently::EventLoop.current.run_queue

      # Cancel running the fiber if it has already been scheduled to run; but
      # only if it was scheduled with a time offset. This is used to cancel the
      # timeout of a wait operation if the waiting fiber is resume before the
      # timeout is triggered.
      run_queue.cancel(self, DEFAULT_RESUME_OPTS)

      run_queue.schedule_immediately(self, result)
    end
  end
end