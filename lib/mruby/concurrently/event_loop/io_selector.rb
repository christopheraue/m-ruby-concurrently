module Concurrently
  # @private
  class EventLoop::IOSelector
    def initialize(event_loop)
      @run_queue = event_loop.run_queue
      @poll = Poll.new
      @fds = {}
      @evaluations = {}
    end

    def awaiting?
      @evaluations.size > 0
    end

    def await_reader(io, evaluation)
      fd = @poll.add(io, Poll::In)
      @fds.store io, fd
      @evaluations.store fd, evaluation
    end

    def await_writer(io, evaluation)
      fd = @poll.add(io, Poll::Out)
      @fds.store io, fd
      @evaluations.store fd, evaluation
    end

    def cancel_reader(io)
      fd = @fds.delete io
      @poll.remove fd
      @evaluations.delete fd
    end

    def cancel_writer(io)
      fd = @fds.delete io
      @poll.remove fd
      @evaluations.delete fd
    end

    def process_ready_in(waiting_time)
      waiting_time = -1 if waiting_time == Float::INFINITY
      if ready = @poll.wait(waiting_time)
        ready.each{ |fd| @run_queue.resume_evaluation! @evaluations[fd], true }
      end
    end
  end
end