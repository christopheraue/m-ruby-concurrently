#!/bin/env ruby

require_relative "_shared/stage"

stage = Stage.new
format = "  %-25s %7d executions in %2.4f seconds"

puts <<-DOC
Benchmarked Code
----------------
  evaluation = Concurrently::Evaluation.current
  proc = proc{ evaluation.resume! }
  conproc = concurrent_proc{ evaluation.resume! }
  
  while elapsed_seconds < 1
    # CODE #
    await_resume!
  end

Results
-------
  # CODE #
DOC

evaluation = Concurrently::Evaluation.current
proc = proc{ evaluation.resume! }
conproc = concurrent_proc{ evaluation.resume! }

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  proc.call
  await_resume!
end
puts sprintf(format, "proc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call
  await_resume!
end
puts sprintf(format, "conproc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_nonblock
  await_resume!
end
puts sprintf(format, "conproc.call_nonblock:", result[:iterations], result[:time])

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_detached
  await_resume!
end
puts sprintf(format, "conproc.call_detached:", result[:iterations], result[:time])

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_and_forget
  await_resume!
end
puts sprintf(format, "conproc.call_and_forget:", result[:iterations], result[:time])