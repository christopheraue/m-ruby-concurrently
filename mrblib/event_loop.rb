module Concurrently
  class EventLoop
    include CallbacksAttachable

    def self.current
      @current ||= new
    end

    def initialize
      reinitialize!
    end

    def reinitialize!
      @start_time = Time.now.to_f
      @run_queue = RunQueue.new self
      @io_watcher = IOWatcher.new
      @fiber = Fiber.new(@run_queue, @io_watcher)
      @fiber_pool = []
      self
    end

    attr_reader :run_queue, :io_watcher

    def lifetime
      Time.now.to_f - @start_time
    end

    def start
      @fiber.resume
    end

    def schedule_now(fiber, result = nil)
      @run_queue.schedule_now(fiber, result)
    end


    # Concurrently executed block of code
    def proc_fiber!
      @fiber_pool.pop || Proc::Fiber.new(@fiber_pool)
    end


    # Watching events

    def watch_events(*args)
      EventWatcher.new(self, *args)
    end
  end
end