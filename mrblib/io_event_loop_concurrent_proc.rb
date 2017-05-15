class IOEventLoop
  class ConcurrentProc < Proc
    def initialize(loop, evaluation_class = ConcurrentEvaluation)
      @loop = loop
      @evaluation_class = evaluation_class
    end

    alias_method :call_consecutively, :call

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
      evaluation = @evaluation_class.new @loop
      evaluation.manually_resume! [self, args, [evaluation]]
      evaluation
    end
  end
end