class IOEventLoop
  class ConcurrentProcFiber < Fiber
    def initialize(loop)
      super() do |concurrent_proc|
        if concurrent_proc == self
          # If concurrent_proc is this very fiber it means this fiber has
          # already been evaluated before its start. In this case just yield
          # back to the cancelling fiber. When this fiber is started when it
          # is the next on schedule it will just finish it without running the
          # block.
          Fiber.yield
        else
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
    end

    def cancel
      # Cancel fiber unless we are already in it
      resume self if Fiber.current != self
      :cancelled
    end
  end
end