class IOEventLoop
  class ConcurrentProc < Proc
    alias_method :call_consecutively, :call

    def call(loop, evaluation_class = ConcurrentEvaluation, evaluation_data = nil)
      evaluation = evaluation_class.new(loop.fresh_concurrent_block, loop, evaluation_data.freeze)
      evaluation.manually_resume! [self, evaluation]
      evaluation
    end
  end
end