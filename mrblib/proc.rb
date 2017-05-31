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
      event_loop = EventLoop.current
      run_queue = event_loop.run_queue

      proc_fiber_pool = event_loop.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)
      evaluation_bucket = []

      result = begin
        previous_evaluation = run_queue.current_evaluation
        run_queue.current_evaluation = nil
        proc_fiber.resume [self, args, evaluation_bucket]
      ensure
        run_queue.current_evaluation = previous_evaluation
      end

      case result
      when Evaluation
        # Only inject the evaluation into the proc fiber if the proc cannot be
        # evaluated without waiting.
        evaluation = @evaluation_class.new(proc_fiber)
        evaluation_bucket << evaluation
        evaluation
      when Exception
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
      evaluation.resume! [self, args, [evaluation]]
      evaluation
    end

    # Schedules evaluation of the concurrent proc
    def call_detached!(*args)
      event_loop = EventLoop.current
      proc_fiber_pool = event_loop.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)

      # run without creating an Evaluation object at first. It will be created
      # if the proc needs to wait for something.
      event_loop.run_queue.schedule_immediately proc_fiber, [self, args]

      nil
    end
  end
end