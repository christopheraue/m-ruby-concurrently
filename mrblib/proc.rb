module Concurrently
  class Proc < ::Proc
    def initialize(evaluation_class = Evaluation)
      @evaluation_class = evaluation_class
    end

    alias_method :__proc_call__, :call

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
      loop = EventLoop.current
      proc_fiber = loop.proc_fiber!
      evaluation_holder = []
      result = proc_fiber.send_to_foreground! [self, args, evaluation_holder]

      if result == proc_fiber
        evaluation = @evaluation_class.new(loop, proc_fiber)
        evaluation_holder << evaluation
        evaluation
      else
        result
      end
    end

    def call_detached(*args)
      loop = EventLoop.current
      proc_fiber = loop.proc_fiber!
      evaluation = @evaluation_class.new(loop, proc_fiber)
      loop.manually_resume! proc_fiber, [self, args, [evaluation]]
      evaluation
    end

    def call_detached!(*args)
      loop = EventLoop.current
      proc_fiber = loop.proc_fiber!
      loop.manually_resume! proc_fiber, [self, args]
      nil
    end
  end
end