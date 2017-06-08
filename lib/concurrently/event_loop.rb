module Concurrently
  # @api public
  # @since 1.0.0
  #
  # @note Although you probably won't need to interact with the event loop
  #   directly (unless you call `Kernel#fork`, see {#reinitialize!}), you need
  #   to understand that it's there.
  #
  # @note Event loops are **not thread safe**. But since each thread has its
  #   own event loop they are not shared anyway.
  #
  # `Concurrently::EventLoop`, like any event loop, is the heart of your
  # application and **must never be interrupted, blocked or overloaded.** A
  # healthy event loop is one that can respond to new events immediately.
  #
  # The loop runs in the background and you won't interact with it directly.
  # Instead, when you call `#wait` or one of the `#await_*` methods the
  # bookkeeping of selecting IOs for readiness or waiting a given amount of
  # time is done for you.
  class EventLoop
    # The event loop of the current thread.
    #
    # This method is thread safe. Each thread returns its own event loop.
    #
    # @example
    #   Concurrently::EventLoop.current
    def self.current
      @current ||= new
    end

    # @private
    #
    # A new instance
    #
    # An event loop is created for every thread automatically. It should not
    # be instantiated manually.
    def initialize
      reinitialize!
    end

    # @note The exclamation mark in its name stands for: Watch out!
    #   This method will break stuff if not used in the right place.
    #
    # Resets the inner state of the event loop.
    #
    # In detail, calling this method for the event loop:
    #
    # * resets its {#lifetime},
    # * clears its internal run queue,
    # * clears its internal list of watched IOs,
    # * clears its internal pool of fibers.
    #
    # While this method clears the list of IOs watched for readiness, the IOs
    # themselves are left untouched. You are responsible for managing IOs (e.g.
    # closing them).
    #
    # @example
    #   fork do
    #     Concurrently::EventLoop.current.reinitialize!
    #     # ...
    #   end
    #
    #   # ...
    def reinitialize!
      @start_time = Time.now.to_f
      @run_queue = RunQueue.new self
      @io_selector = IOSelector.new self
      @proc_fiber_pool = ProcFiberPool.new self
      @fiber = Fiber.new @run_queue, @io_selector, @proc_fiber_pool
      self
    end

    # @private
    #
    # Its run queue keeping track of and scheduling all concurrent procs
    attr_reader :run_queue

    # @private
    #
    # Its selector to watch IOs.
    attr_reader :io_selector

    # @private
    #
    # Its fiber running the actual loop
    attr_reader :fiber

    # @private
    #
    # Its pool of reusable fibers to run the code of concurrent procs in.
    attr_reader :proc_fiber_pool

    # The lifetime of this event loop in seconds
    #
    # @example
    #   Concurrently::EventLoop.current.lifetime # => 2.3364
    def lifetime
      Time.now.to_f - @start_time
    end
  end
end