# Concurrently adds a few methods to "Kernel" which makes them available
# for every object.
#
# This is part of the main API of Concurrently.
#
# @api public
module Kernel
  # @!method concurrently(*args, &block)
  #
  # Executes code concurrently in the background.
  #
  # This is a shortcut for {Concurrently::Proc#call_detached!}.
  #
  # @return [nil]
  #
  # @example
  #   concurrently(a,b,c) do |a,b,c|
  #     # ...
  #   end
  def concurrently(*args)
    # Concurrently::Proc.new claims the method's block just like Proc.new does
    Concurrently::Proc.new.call_detached! *args
  end

  # Creates a concurrent proc to execute code concurrently
  def concurrent_proc(evaluation_class = Concurrently::Proc::Evaluation) # &block
    # Concurrently::Proc.new claims the method's block just like Proc.new does
    Concurrently::Proc.new(evaluation_class)
  end

  # Suspends the current concurrent proc or fiber until it is resumed manually
  def await_scheduled_resume!(opts = {})
    run_queue = Concurrently::EventLoop.current.run_queue
    fiber = Fiber.current

    if seconds = opts[:within]
      timeout_result = opts.fetch(:timeout_result, Concurrently::Proc::TimeoutError)
      run_queue.schedule_deferred(fiber, seconds, timeout_result)
    end

    result = fiber.yield_to_event_loop!

    # If result is this very fiber it means this fiber has been evaluated
    # prematurely.
    if result == fiber
      run_queue.cancel fiber # in case the fiber has already been scheduled to resume

      # Generally, throw-catch is faster than raise-rescue if the code needs to
      # play back the call stack, i.e. the throw resp. raise is invoked. If not
      # playing back the call stack, a begin block is faster than a catch
      # block. Since we won't jump out of the proc above most of the time, we
      # go with raise. It is rescued in the proc fiber.
      raise Concurrently::Proc::Fiber::Cancelled, '', []
    elsif result == Concurrently::Proc::TimeoutError
      raise Concurrently::Proc::TimeoutError, "evaluation timed out after #{seconds} second(s)"
    else
      result
    end
  ensure
    if seconds
      run_queue.cancel fiber
    end
  end

  # Suspends the current concurrent proc or fiber for the given number of
  # seconds
  def wait(seconds)
    run_queue = Concurrently::EventLoop.current.run_queue
    fiber = Fiber.current
    run_queue.schedule_deferred(fiber, seconds)
    await_scheduled_resume!
  ensure
    run_queue.cancel fiber
  end
end