module Concurrently
  # @private
  # The fiber pool grows dynamically if its internal store of fibers is empty.
  class EventLoop::ProcFiberPool
    def initialize(event_loop)
      @event_loop = event_loop
      @fibers = []
    end

    def take_fiber
      @fibers.pop or Proc::Fiber.new(self)
    end

    def return(fiber)
      @fibers << fiber
    end
  end
end