class IOEventLoop
  class ConcurrentProcFiber < Fiber
    def initialize(loop, run_queue)
      super() do |concurrent_proc|
        if Fiber === concurrent_proc
          # If concurrent_proc is a Fiber it means this fiber has already been
          # evaluated before its start. Cancel the scheduled start of this
          # fiber and transfer back to the given fiber.
          run_queue.cancel self
          concurrent_proc.transfer
        end

        result = begin
          yield
        rescue Exception => e
          loop.trigger :error, e
          e
        end

        concurrent_proc.evaluate_to result
      end
    end

    def cancel
      # Cancel fiber unless we are already in it. If we are in fiber,
      # transferring to it is a no-op.
      transfer Fiber.current
    end
  end
end