class IOEventLoop
  class IOWatcher
    def initialize
      @readers = {}
      @writers = {}
      @fibers = {}
    end

    def awaiting?
      @fibers.any?
    end

    def await_reader(io, fiber)
      @readers[fiber] = io
      @fibers[io] = fiber
    end

    def await_writer(io, fiber)
      @writers[fiber] = io
      @fibers[io] = fiber
    end

    def cancel_reader(io)
      @readers.delete @fibers.delete io
    end

    def cancel_writer(io)
      @writers.delete @fibers.delete io
    end

    def process_ready_in(waiting_time)
      if selected = IO.select(@readers.values, @writers.values, nil, waiting_time)
        selected[0].each{ |readable| @fibers[readable].transfer } unless selected[0].empty?
        selected[1].each{ |writable| @fibers[writable].transfer } unless selected[1].empty?
      end
    end
  end
end