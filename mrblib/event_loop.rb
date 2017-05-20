module Concurrently
  class EventLoop
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
      @proc_fiber_pool = []
      self
    end

    attr_reader :run_queue, :io_watcher, :fiber, :proc_fiber_pool

    def lifetime
      Time.now.to_f - @start_time
    end
  end
end