class IOEventLoop
  class Concurrency
    class ReadabilityFuture < Future
      def initialize(concurrency, io)
        super concurrency
        @io = io
      end

      def result(*args)
        @concurrency.loop.attach_reader(@io) { @concurrency.loop.detach_reader(@io); @concurrency.resume_with :readable }
        super
      end

      def cancel
        @concurrency.loop.detach_reader @io
        @concurrency.resume_with :cancelled
      end
    end
  end
end