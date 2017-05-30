module Concurrently
  class EventLoop::IOSelector
    def initialize(event_loop)
      @run_queue = event_loop.run_queue
      @selector = NIO::Selector.new
    end

    def awaiting?
      not @selector.empty?
    end

    def await_reader(io, evaluation)
      monitor = @selector.register(io, :r)
      monitor.value = evaluation
    end

    def await_writer(io, evaluation)
      monitor = @selector.register(io, :w)
      monitor.value = evaluation
    end

    def cancel_reader(io)
      @selector.deregister(io)
    end

    def cancel_writer(io)
      @selector.deregister(io)
    end

    def process_ready_in(waiting_time)
      @selector.select(waiting_time) do |monitor|
        @run_queue.resume_evaluation! monitor.value, true
      end
    end
  end
end