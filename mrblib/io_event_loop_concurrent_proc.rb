class IOEventLoop
  class ConcurrentProc < Proc
    def initialize(loop, evaluation_class = nil)
      @loop = loop
      @evaluation_class = evaluation_class
    end

    alias_method :call_consecutively, :call

    def call
      evaluation = @evaluation_class.new @loop
      evaluation.manually_resume! [self, evaluation]
      evaluation
    end
  end
end