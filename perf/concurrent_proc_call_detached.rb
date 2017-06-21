#!/bin/env ruby

require_relative "_shared/stage"

stage = Stage.new

conproc = concurrent_proc{}

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_detached
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"