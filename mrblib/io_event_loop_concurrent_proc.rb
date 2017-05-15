class IOEventLoop
  class ConcurrentProc < Proc
    def initialize(loop, evaluation_class = ConcurrentEvaluation)
      @loop = loop
      @evaluation_class = evaluation_class
    end

    alias_method :call_consecutively, :call

    def call(*args)
      case immediate_result = call_nonblock(*args)
      when ConcurrentEvaluation
        immediate_result.await_result
      else
        immediate_result
      end
    end

    alias [] call

    def call_nonblock(*args)
      concurrent_block = @loop.concurrent_block!
      evaluation_holder = []
      result = concurrent_block.send_to_foreground! [self, args, evaluation_holder]

      if result == concurrent_block
        evaluation = @evaluation_class.new(@loop, concurrent_block)
        evaluation_holder << evaluation
        evaluation
      else
        result
      end
    end

    def call_detached(*args)
      concurrent_block = @loop.concurrent_block!
      evaluation = @evaluation_class.new(@loop, concurrent_block)
      @loop.manually_resume! concurrent_block, [self, args, [evaluation]]
      evaluation
    end
  end
end