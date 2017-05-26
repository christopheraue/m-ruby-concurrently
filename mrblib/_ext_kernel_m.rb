module Kernel
  # mruby does not support Proc.new without a block

  def concurrently(*args, &block)
    Concurrently::Proc.new(&block).call_detached! *args
  end

  def concurrent_proc(evaluation_class = Concurrently::Proc::Evaluation, &block)
    Concurrently::Proc.new(evaluation_class, &block)
  end
end