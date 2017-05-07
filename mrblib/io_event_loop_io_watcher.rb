class IOEventLoop
  class IOWatcher
    def initialize(loop)
      @loop = loop
      @readers = {}
      @writers = {}
      @fibers = {}
    end

    def awaiting?
      @fibers.any?
    end

    def await_reader(fiber, io)
      @readers[fiber] = io
      @fibers[io] = fiber
    end

    def await_writer(fiber, io)
      @writers[fiber] = io
      @fibers[io] = fiber
    end

    def cancel(fiber)
      @fibers.delete @readers.delete fiber
      @fibers.delete @writers.delete fiber
    end

    def process_ready_in(waiting_time)
      if selected = IO.select(@readers.values, @writers.values, nil, waiting_time)
        selected[0].each{ |readable| @fibers[readable].transfer true } unless selected[0].empty?
        selected[1].each{ |writable| @fibers[writable].transfer true } unless selected[1].empty?
      end
    end
  end
end