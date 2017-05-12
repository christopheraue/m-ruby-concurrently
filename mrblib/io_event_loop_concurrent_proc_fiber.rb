class IOEventLoop
  class ConcurrentProcFiber < Fiber
    def initialize(loop)
      super() do |start_argument|
        if start_argument == self
          # If we are given with this very fiber when starting the fiber for
          # real it means this fiber is already evaluated right now before its
          # start. In this case just yield back to the cancelling fiber.
          Fiber.yield

          # When this fiber is started when it is the next on schedule it will
          # just finish without running the block.
        else
          result = begin
            yield
          rescue Exception => e
            loop.trigger :error, e
            e
          end

          future.evaluate_to result if future

          # yields back to the event loop fiber from where it was started
        end
      end

      self.loop = loop
    end

    attr_accessor :loop, :future
    private :loop, :loop=, :future, :future=

    def cancel
      if Fiber.current != self
        # Cancel fiber by resuming it with itself as argument
        resume self
      end
      :cancelled
    end

    def to_future(klass = ConcurrentFuture, data = {})
      self.future = klass.new(self, loop, data)
    end
  end
end