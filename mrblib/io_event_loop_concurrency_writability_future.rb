class IOEventLoop
  class Concurrency
    class WritabilityFuture < Future
      def initialize(concurrency, io)
        super concurrency
        @io = io
      end

      def result(*args)
        @concurrency.loop.attach_writer(@io) { @concurrency.loop.detach_writer(@io); @concurrency.resume_with :writable }
        super
      end

      def cancel
        @concurrency.loop.detach_writer @io
        @concurrency.resume_with :cancelled
      end
    end
  end
end