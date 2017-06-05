# @api mruby_patches
# @since 1.0.0
module Kernel
  # Reimplements Kernel#concurrently. mruby does not support Proc.new without
  # a block.
  private def concurrently(*args, &block)
    Concurrently::Proc.new(&block).call_and_forget *args
  end

  # Reimplements Kernel#concurrent_proc. mruby does not support Proc.new without
  # a block.
  private def concurrent_proc(evaluation_class = Concurrently::Proc::Evaluation, &block)
    Concurrently::Proc.new(evaluation_class, &block)
  end
end