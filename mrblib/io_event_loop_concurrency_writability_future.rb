class IOEventLoop
  class Concurrency
    class WritabilityFuture < Future
      def initialize(concurrency, run_queue, io)
        super concurrency, run_queue
        @io = io
      end

      def result(*args)
        @concurrency.loop.attach_writer(@io) do
          @concurrency.loop.detach_writer(@io)
          @concurrency.fiber.resume :writable
        end
        super
      end

      def cancel
        @concurrency.loop.detach_writer @io
        super
      end
    end
  end
end