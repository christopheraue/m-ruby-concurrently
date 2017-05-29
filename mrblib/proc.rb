module Concurrently
  if Object.const_defined? :MRUBY_VERSION
    # @api mruby
    class Proc; end
  else
    class Proc < ::Proc
      # @api private
      # Calls the concurrent proc like a normal proc
      alias_method :__proc_call__, :call
    end
  end

  # A concurrent Proc is like a regular Proc except its block of code is
  # evaluated concurrently. Its evaluation can wait for other stuff to happen
  # (e.g. result of another concurrent proc or readiness of an IO) without
  # blocking the execution of its thread.
  class Proc
    include CallbacksAttachable

    # A new instance of Concurrently::Proc
    def initialize(evaluation_class = Evaluation)
      @evaluation_class = evaluation_class
    end

    # Evaluates of the concurrent proc
    def call(*args)
      case immediate_result = call_nonblock(*args)
      when Evaluation
        immediate_result.await_result
      else
        immediate_result
      end
    end

    alias [] call

    # Starts evaluation of the concurrent proc
    def call_nonblock(*args)
      proc_fiber_pool = EventLoop.current.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)
      evaluation_bucket = []
      result = proc_fiber.resume [self, args, evaluation_bucket]

      if result == proc_fiber
        # Only create an evaluation object and inject it into the proc fiber
        # if the proc cannot be evaluated without waiting.
        evaluation = @evaluation_class.new(proc_fiber)
        evaluation_bucket << evaluation
        evaluation
      elsif Exception === result
        raise result
      else
        result
      end
    end

    # Schedules evaluation of the concurrent proc
    def call_detached(*args)
      proc_fiber_pool = EventLoop.current.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)
      evaluation = @evaluation_class.new(proc_fiber)
      proc_fiber.schedule_resume! [self, args, [evaluation]]
      evaluation
    end

    # Schedules evaluation of the concurrent proc
    def call_detached!(*args)
      proc_fiber_pool = EventLoop.current.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)
      proc_fiber.schedule_resume! [self, args]
      nil
    end
  end
end