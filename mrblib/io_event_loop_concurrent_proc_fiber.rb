class IOEventLoop
  class ConcurrentProcFiber < Fiber
    def initialize(loop, run_queue)
      super() do |concurrent_proc|
        if Fiber === concurrent_proc
          # If evaluator is a fiber it means this fiber has just cancelled
          # before its start. In this case cancel the scheduled start and
          # yield back to the fiber that is responsible for cancelling.
          run_queue.cancel self
          Fiber.yield
        end

        result = begin
          yield
        rescue Exception => e
          loop.trigger :error, e
          e
        end

        concurrent_proc.evaluate_to result

        # yields back to the event loop fiber from where it was started
      end
    end

    def cancel
      # Cancel fiber unless we are already in it
      fiber = Fiber.current
      resume fiber if fiber != self
      :cancelled
    end
  end
end