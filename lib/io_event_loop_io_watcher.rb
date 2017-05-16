class IOEventLoop
  class IOWatcher
    def initialize
      @selector = NIO::Selector.new
    end

    def awaiting?
      not @selector.empty?
    end

    def await_reader(io, fiber)
      monitor = @selector.register(io, :r)
      monitor.value = fiber
    end

    def await_writer(io, fiber)
      monitor = @selector.register(io, :w)
      monitor.value = fiber
    end

    def cancel_reader(io)
      @selector.deregister(io)
    end

    def cancel_writer(io)
      @selector.deregister(io)
    end

    def process_ready_in(waiting_time)
      @selector.select(waiting_time) do |monitor|
        monitor.value.send_to_foreground! true
      end
    end
  end
end