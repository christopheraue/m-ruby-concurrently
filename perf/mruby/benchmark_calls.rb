class Stage
  def gc_disabled
    GC.start
    GC.disable
    yield
  ensure
    GC.enable
  end

  def execute(opts = {})
    seconds = opts[:seconds] || 1
    event_loop = Concurrently::EventLoop.current
    event_loop.reinitialize!
    iterations = 0
    start_time = event_loop.lifetime
    end_time = start_time + seconds
    while event_loop.lifetime < end_time
      yield
      iterations += 1
    end
    stop_time = event_loop.lifetime
    { iterations: iterations, time: (stop_time-start_time) }
  end

  def measure(opts = {}) # &test
    gc_disabled do
      execute(opts){ yield }
    end
  end
end

stage = Stage.new
format = "  %-25s %7d executions in %2.4f seconds"

puts <<-DOC
Benchmarked Code
----------------
  proc = proc{}
  conproc = concurrent_proc{}
  
  while elapsed_seconds < 1
    # CODE #
  end

Results
-------
  # CODE #
DOC

proc = proc{}
conproc = concurrent_proc{}

result = stage.measure(seconds: 1) do
  proc.call
end
puts sprintf(format, "proc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call
end
puts sprintf(format, "conproc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call_nonblock
end
puts sprintf(format, "conproc.call_nonblock:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call_detached
end
puts sprintf(format, "conproc.call_detached:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call_and_forget
end
puts sprintf(format, "conproc.call_and_forget:", result[:iterations], result[:time])