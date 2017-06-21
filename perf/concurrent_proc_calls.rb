#!/bin/env ruby

require_relative "_shared/stage"

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

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  proc.call
end
puts sprintf(format, "proc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call
end
puts sprintf(format, "conproc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_nonblock
end
puts sprintf(format, "conproc.call_nonblock:", result[:iterations], result[:time])

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_detached
end
puts sprintf(format, "conproc.call_detached:", result[:iterations], result[:time])

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_and_forget
end
puts sprintf(format, "conproc.call_and_forget:", result[:iterations], result[:time])

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  Fiber.new{}
end
puts sprintf(format, "Fiber.new{}:", result[:iterations], result[:time])