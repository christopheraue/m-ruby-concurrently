class IOEventLoop
  class Concurrency
    include Comparable

    def initialize(loop, run_queue) #&block
      @loop = loop
      @run_queue = run_queue
      @fiber = Fiber.new do
        begin
          yield
        rescue Exception => e
          loop.trigger :error, e
        end
      end
    end

    def schedule_at(schedule_time, schedule_result = nil)
      @schedule_time = schedule_time
      @scheduled = true
      @schedule_result = schedule_result
      @run_queue.schedule self
    end

    attr_reader :schedule_time
    alias to_f schedule_time

    def scheduled_resume
      @fiber.resume @schedule_result if @scheduled
    end

    def cancel_schedule
      @scheduled = false
      @schedule_result = nil
    end

    attr_reader :scheduled
    alias scheduled? scheduled
    undef scheduled

    def <=>(other)
      @schedule_time <=> other.to_f
    end

    def resume_with(result)
      @waits = false
      cancel_schedule
      @fiber.resume result
    end

    def await_result(opts = {})
      @waits = true

      if seconds = opts[:within]
        timeout_result = opts.fetch(:timeout_result, TimeoutError.new("waiting timed out after #{seconds} second(s)"))
        schedule_at @loop.wall_clock.now+seconds, timeout_result
      end

      result = Fiber.yield
      (CancelledError === result) ? raise(result) : result
    end

    attr_reader :waits
    alias waits? waits
    undef waits

    def cancel(reason = "waiting cancelled")
      resume_with CancelledError.new(reason)
      :cancelled
    end

    def await_readable(io, *args)
      @loop.attach_reader(io) { @loop.detach_reader(io); resume_with :readable }
      await_result *args
    end

    def cancel_awaiting_readable(io)
      @loop.detach_reader io
      resume_with :cancelled
    end

    def await_writable(io, *args)
      @loop.attach_writer(io) { @loop.detach_writer(io); resume_with :writable }
      await_result *args
    end

    def cancel_awaiting_writable(io)
      @loop.detach_writer io
      resume_with :cancelled
    end
  end
end