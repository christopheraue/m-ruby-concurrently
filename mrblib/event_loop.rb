module Concurrently
  # Every thread has a single event loop attached to it. This loop does the
  # bulk of coordination between all concurrent procs. Its the good old event
  # loop responsible for selecting/polling IOs for a given amount of time.
  #
  # It runs in the background and you won't interact with it directly. Instead,
  # when you call one of the #await_* methods the bookkeeping of selecting IOs
  # for readiness or waiting a given amount of time is done for you.
  #
  # @note Unless you fork the process you probably won't need to deal with the
  #   event loop directly.
  class EventLoop
    # The event loop of the current thread.
    #
    # @api public
    #
    # @example
    #   Concurrently::EventLoop.current
    def self.current
      @current ||= new
    end

    # A new instance
    #
    # @private
    #
    # An event loop is created for every thread automatically. It should not
    # be instantiated manually.
    def initialize
      reinitialize!
    end

    # Resets the inner state of the event loop.
    #
    # @api public
    #
    # This method should be called right after creating a fork. The fork
    # inherits the main thread and with it the event loop with all its internal
    # state from the parent. This is the a problem since we probably do not
    # want to continue watching the parent's IOs. Also, the fibers in the run
    # queue are not transferable between parent and fork and running them
    # raises a "fiber called across stack rewinding barrier" error.
    #
    # In detail, calling this method:
    #
    # * resets its {#lifetime},
    # * clears its internal run queue,
    # * clears its internal list of IOs to watch,
    # * clears its internal pool of fibers.
    #
    # While this method clears the list of IOs to be watched for readiness,
    # the IOs themselves are left untouched. You are responsible for managing
    # IOs like when not using this library.
    #
    # @example
    #   r,w = IO.pipe
    #
    #   fork do
    #     Concurrently::EventLoop.current.reinitialize!
    #     r.close
    #     # ...
    #   end
    #
    #   w.close
    #   # ...
    def reinitialize!
      @start_time = Time.now.to_f
      @run_queue = RunQueue.new self
      @io_selector = IOSelector.new self
      @fiber = Fiber.new(@run_queue, @io_selector)
      @proc_fiber_pool = []
      self
    end

    # Its run queue keeping track of and scheduling all concurrent procs
    #
    # @api private
    attr_reader :run_queue

    # Its selector to watch IOs.
    #
    # @api private
    attr_reader :io_selector

    # Its fiber running the actual loop
    #
    # @api private
    attr_reader :fiber

    # Its pool of reusable fibers to run the code of concurrent procs in.
    #
    # @api private
    attr_reader :proc_fiber_pool

    # The lifetime of this event loop in seconds
    #
    # @api public
    #
    # @example
    #   Concurrently::EventLoop.current.lifetime # => 2.3364
    def lifetime
      Time.now.to_f - @start_time
    end
  end
end