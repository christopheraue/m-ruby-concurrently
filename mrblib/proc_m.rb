module Concurrently
  class Proc
    def initialize(evaluation_class = Evaluation, &proc)
      @evaluation_class = evaluation_class
      @proc = proc
    end

    def arity
      @proc.arity
    end

    def __proc_call__(*args)
      @proc.call *args
    end
  end
end