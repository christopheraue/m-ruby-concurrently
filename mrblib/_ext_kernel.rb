module Kernel
  def concurrently(*args)
    # Concurrently::Proc.new claims the method's block just like Proc.new does
    Concurrently::Proc.new.call_detached! *args
  end

  def concurrent_proc(evaluation_class = Concurrently::Proc::Evaluation) # &block
    # Concurrently::Proc.new claims the method's block just like Proc.new does
    Concurrently::Proc.new(evaluation_class)
  end

  def await_manual_resume!(opts = {})
    Concurrently::EventLoop.current.await_manual_resume! opts
  end

  def wait(seconds)
    Concurrently::EventLoop.current.wait seconds
  end
end