# @api mruby
#
# mruby does not support Proc.new without a block. We have to re-implement the
# following methods with an explicit block argument.
module Kernel
  private def concurrently(*args, &block)
    Concurrently::Proc.new(&block).call_and_forget *args
  end

  private def concurrent_proc(evaluation_class = Concurrently::Proc::Evaluation, &block)
    Concurrently::Proc.new(evaluation_class, &block)
  end
end