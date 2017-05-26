module Concurrently
  if Object.const_defined? :MRUBY_VERSION
    # mruby's Proc does not support instance variables. So, whe have to make
    # it a normal class that does not inherit from Proc :(
    class Proc; end
  else
    class Proc < ::Proc
      alias_method :__proc_call__, :call
    end
  end

  class Proc
    include CallbacksAttachable

    def initialize(evaluation_class = Evaluation)
      @evaluation_class = evaluation_class
    end

    def call(*args)
      case immediate_result = call_nonblock(*args)
      when Evaluation
        immediate_result.await_result
      else
        immediate_result
      end
    end

    alias [] call

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

    def call_detached(*args)
      proc_fiber_pool = EventLoop.current.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)
      evaluation = @evaluation_class.new(proc_fiber)
      proc_fiber.schedule_resume! [self, args, [evaluation]]
      evaluation
    end

    def call_detached!(*args)
      proc_fiber_pool = EventLoop.current.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)
      proc_fiber.schedule_resume! [self, args]
      nil
    end
  end
end