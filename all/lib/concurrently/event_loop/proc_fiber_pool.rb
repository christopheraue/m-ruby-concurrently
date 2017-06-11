module Concurrently
  # @private
  # The fiber pool grows dynamically if its internal store of fibers is empty.
  class EventLoop::ProcFiberPool
    # Number of fibers allowed to be created per event loop iteration.
    CREATIONS_PER_ITERATION = 1

    def initialize(event_loop)
      @event_loop = event_loop
      @fibers = []
      @iteration_quota = CREATIONS_PER_ITERATION
    end

    def reset_iteration_quota
      @iteration_quota = CREATIONS_PER_ITERATION
    end

    def take_fiber
      @fibers.pop or begin
        # Creating a new fiber only if we are within the iteration quota
        # encourages reuse of fibers by potentially reusing a fiber that will
        # be returned during the next iteration. This is untested in the suite
        # but has a huge impact on performance.
        if @iteration_quota > 0
          @iteration_quota -= 1
          Proc::Fiber.new self
        else
          @event_loop.run_queue.schedule_immediately Concurrently::Evaluation.current
          await_resume!
          take_fiber
        end
      end
    end

    def return(fiber)
      @fibers << fiber
    end
  end
end