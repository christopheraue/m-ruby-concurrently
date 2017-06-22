#!/bin/env ruby

require_relative "_shared/stage"

stage = Stage.new
format = "  %-25s %7d executions in %2.4f seconds"

puts <<-DOC
Benchmarked Code
----------------
  proc = proc{ wait 0 }
  conproc = concurrent_proc{ wait 0 }
  
  while elapsed_seconds < 1
    # CODE #
    wait 0
  end

Results
-------
  # CODE #
DOC

proc = proc{ wait 0 }
conproc = concurrent_proc{ wait 0 }

result = stage.measure(seconds: 1) do
  proc.call
  wait 0
end
puts sprintf(format, "proc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call
  wait 0
end
puts sprintf(format, "conproc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call_nonblock
  wait 0
end
puts sprintf(format, "conproc.call_nonblock:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call_detached
  wait 0
end
puts sprintf(format, "conproc.call_detached:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call_and_forget
  wait 0
end
puts sprintf(format, "conproc.call_and_forget:", result[:iterations], result[:time])