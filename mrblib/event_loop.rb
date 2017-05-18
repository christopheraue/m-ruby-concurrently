module Concurrently
  class EventLoop
    include CallbacksAttachable

    def self.current
      @current ||= new
    end

    def initialize
      reinitialize!
      @empty_call_stack = [].freeze
    end

    def reinitialize!
      @start_time = Time.now.to_f
      @run_queue = RunQueue.new self
      @io_watcher = IOWatcher.new
      @loop_fiber = Fiber.new(@run_queue, @io_watcher)
      @fiber_pool = []
      true
    end

    def lifetime
      Time.now.to_f - @start_time
    end


    # Concurrently executed block of code
    def proc_fiber!
      @fiber_pool.pop || Proc::Fiber.new(self, @fiber_pool)
    end

    def concurrently(*args) # &block
      # Concurrently::Proc.new claims the method's block just like Proc.new does
      Proc.new(self).call_detached! *args
    end

    def concurrent_proc(evaluation_class = Proc::Evaluation) # &block
      # Concurrently::Proc.new claims the method's block just like Proc.new does
      Proc.new(self, evaluation_class)
    end


    # Awaiting stuff

    def await_manual_resume!(opts = {})
      fiber = Fiber.current

      if seconds = opts[:within]
        timeout_result = opts.fetch(:timeout_result, Proc::TimeoutError)
        @run_queue.schedule(fiber, seconds, timeout_result)
      end

      result = fiber.send_to_background! @loop_fiber

      # If result is this very fiber it means this fiber has been evaluated
      # prematurely.
      if result == Proc::TimeoutError
        raise Proc::TimeoutError, "evaluation timed out after #{seconds} second(s)"
      elsif result == fiber
        @run_queue.cancel fiber # in case the fiber has already been scheduled to resume
        raise Proc::Fiber::Cancelled, '', @empty_call_stack
      else
        result
      end
    ensure
      if seconds
        @run_queue.cancel fiber
      end
    end

    def manually_resume!(fiber, result = nil)
      @run_queue.schedule_now(fiber, result)
    end

    def wait(seconds)
      fiber = Fiber.current
      @run_queue.schedule(fiber, seconds)
      await_manual_resume!
    ensure
      @run_queue.cancel fiber
    end

    def await_readable(io, opts = {})
      fiber = Fiber.current
      @io_watcher.await_reader(io, fiber)
      await_manual_resume! opts
    ensure
      @io_watcher.cancel_reader(io)
    end

    def await_writable(io, opts = {})
      fiber = Fiber.current
      @io_watcher.await_writer(io, fiber)
      await_manual_resume! opts
    ensure
      @io_watcher.cancel_writer(io)
    end

    def await_event(subject, event, opts = {})
      fiber = Fiber.current
      callback = subject.on(event) { |_,result| @run_queue.schedule_now(fiber, result) }
      await_manual_resume! opts
    ensure
      callback.cancel
    end


    # Watching events

    def watch_events(*args)
      EventWatcher.new(self, *args)
    end
  end
end