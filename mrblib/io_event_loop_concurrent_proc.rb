class IOEventLoop
  class ConcurrentProc < Proc
    def initialize(loop, evaluation_class = ConcurrentEvaluation)
      @loop = loop
      @evaluation_class = evaluation_class
    end

    alias_method :call_consecutively, :call

    def call(*args)
      evaluation = @evaluation_class.new @loop
      evaluation.manually_resume! [self, args, evaluation]
      evaluation
    end

    alias [] call
  end
end