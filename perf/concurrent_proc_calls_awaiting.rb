#!/bin/env ruby

require_relative "_shared/stage"

stage = Stage.new
format = "  %-25s %7d executions in %2.4f seconds"

puts <<-DOC
Benchmarked Code
----------------
  conproc = concurrent_proc{ wait 0 }
  
  while elapsed_seconds < 1
    # CODE #
    wait 0 # to enter the event loop
  end

Results
-------
  # CODE #
DOC

conproc = concurrent_proc{ wait 0 }

result = stage.measure(seconds: 1) do
  conproc.call
  # no need to enter the event loop manually. It already happens in #call
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