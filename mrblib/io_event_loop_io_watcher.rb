class IOEventLoop
  class IOWatcher
    def initialize(loop)
      @loop = loop
      @readers = {}
      @writers = {}
    end

    def watches?
      @readers.any? or @writers.any?
    end

    def watch_reader(reader, fiber)
      @readers[reader] = fiber
    end

    def cancel_watching_reader(reader)
      @readers.delete reader
    end

    def watch_writer(writer, fiber)
      @writers[writer] = fiber
    end

    def cancel_watching_writer(writer)
      @writers.delete writer
    end

    def process_ready_in(waiting_time)
      if selected = IO.select(@readers.keys, @writers.keys, nil, waiting_time)
        selected[0].each{ |readable_io| @readers[readable_io].transfer true } unless selected[0].empty?
        selected[1].each{ |writable_io| @writers[writable_io].transfer true } unless selected[1].empty?
      end
    end
  end
end