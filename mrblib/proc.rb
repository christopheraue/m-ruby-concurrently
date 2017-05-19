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
      proc_fiber = EventLoop.current.proc_fiber!
      evaluation_holder = []
      result = proc_fiber.send_to_foreground! [self, args, evaluation_holder]

      if result == proc_fiber
        evaluation = @evaluation_class.new(proc_fiber)
        evaluation_holder << evaluation
        evaluation
      else
        result
      end
    end

    def call_detached(*args)
      proc_fiber = EventLoop.current.proc_fiber!
      evaluation = @evaluation_class.new(proc_fiber)
      proc_fiber.manually_resume! [self, args, [evaluation]]
      evaluation
    end

    def call_detached!(*args)
      EventLoop.current.proc_fiber!.manually_resume! [self, args]
      nil
    end
  end
end