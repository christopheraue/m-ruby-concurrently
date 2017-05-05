class IOEventLoop
  class Concurrency
    class ReadabilityFuture < Future
      def initialize(concurrency, run_queue, io)
        super concurrency, run_queue
        @io = io
      end

      def result(*args)
        @concurrency.loop.attach_reader(@io) do
          @concurrency.loop.detach_reader(@io)
          @concurrency.fiber.transfer :readable
        end
        super
      end

      def cancel
        @concurrency.loop.detach_reader @io
        super
      end
    end
  end
end