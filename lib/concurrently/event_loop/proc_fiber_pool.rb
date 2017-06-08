module Concurrently
  # @private
  class EventLoop::ProcFiberPool < Array
    def initialize(event_loop)
      @event_loop = event_loop
    end

    def pop
      super or Proc::Fiber.new(self)
    end
  end
end