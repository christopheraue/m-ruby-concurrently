module Concurrently
  # @api public
  #
  # @note Although you probably won't need to interact with the event loop
  #   directly (unless you call `Kernel#fork`, see {#reinitialize!}), you need
  #   to understand that it's there.
  #
  # `Concurrently::EventLoop`, like any event loop, is the heart of your
  # application and **must never be interrupted, blocked or overloaded.** A
  # healthy event loop is one that can respond to new events immediately.
  #
  # The event loop is responsible for selecting/polling IOs and waiting for
  # a given amount of time. It does all the coordination between concurrent
  # procs. Every thread has a single event loop attached to it.
  #
  # The loop runs in the background and you won't interact with it directly.
  # Instead, when you call one of the #await_* methods the bookkeeping of
  # selecting IOs for readiness or waiting a given amount of time is done for
  # you.
  #
  # To make sure your event loop functions properly, keep the following in
  # mind:
  #
  # # Interrupted by errors
  #
  # Every concurrent proc rescues all errors happening during its evaluation.
  # They won't leak to the event loop and will not tear it down. In a limited
  # number of very particular cases an error happens right when switching from
  # one concurrent proc to another. If this happens the event loop is indeed
  # teared down and exits by raising an {Concurrently::Error}. This is either
  # a sign that there is a bug in this library, you fumbled around with its
  # internals or you did some custom stuff with fibers interfering with the
  # fibers of concurrent procs.
  #
  #
  # # Blocked by IO
  #
  # When doing IO always use the `#*_nonblock` variants to read from or write
  # to them, like `IO#read_nonblock` or `IO#write_nonblock`, in conjunction
  # with {IO#await_readable} and {IO#await_writable}.
  #
  # ```
  # def read(io, maxlen = 32768)
  #   io.read_nonblock(maxlen)
  # rescue IO::WaitReadable
  #   io.await_readable
  #   retry
  # end
  # ```
  #
  # This way, while the the IO is not ready, control is given back to the event
  # loop so it can continue evaluating other code in the meantime.
  #
  #
  # # Overloaded by too many, too expensive operations
  #
  # Imagine a concurrent proc with an infinite loop:
  #
  # ```
  # evaluation = concurrent_proc do
  #   loop do
  #     puts "To infinity! And beyond!"
  #   end
  # end.call_detached
  #
  # concurrently do
  #   evaluation.conclude_to :cancelled
  # end
  # ```
  #
  # When it is scheduled to run it runs and runs and runs and never finishes.
  # The event loop is never entered again and the other concurrent proc
  # concluding the evaluation is never started.
  #
  # A less extreme example is something like:
  #
  # ```
  # concurrent_proc do
  #   loop do
  #     wait 0.1
  #     puts "iteration started at: #{Time.now.strftime('%H:%M:%S.%L')}"
  #     concurrently do
  #       sleep 1 # defers the entire event loop
  #     end
  #   end
  # end.call
  #
  # # => iteration started at: 16:08:17.704
  # # => iteration started at: 16:08:18.705
  # # => iteration started at: 16:08:19.705
  # # => iteration started at: 16:08:20.705
  # # => iteration started at: 16:08:21.706
  # ```
  #
  # This is a timer that is supposed to run every 0.1 seconds and creates
  # another concurrent evaluation that takes a full second to complete. But
  # since it takes so long the loop also only gets a chance to run every
  # second leading to a delay of 0.9 seconds between the time the loop is
  # supposed to run and the time it actually ran.
  class EventLoop
    # The event loop of the current thread.
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

    # @note The exclamation mark in its name stands for: Watch out!
    #   This method will break stuff if not used in the right place.
    #
    # Resets the inner state of the event loop.
    #
    # This method should be called right after calling `Kernel#fork`. The fork
    # inherits the main thread and with it the event loop with all its internal
    # state from the parent. This is the a problem since we probably do not
    # want to continue watching the parent's IOs. Also, the fibers in the run
    # queue are not transferable between parent and fork and running them
    # raises a "fiber called across stack rewinding barrier" error.
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
    # closing them) like when not using this library.
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
    # @example
    #   Concurrently::EventLoop.current.lifetime # => 2.3364
    def lifetime
      Time.now.to_f - @start_time
    end
  end
end