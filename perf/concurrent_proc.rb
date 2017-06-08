#!/bin/env ruby

require_relative "_shared/stage"

stage = Stage.new

conproc = concurrent_proc{}

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call
end

puts "           #call: #{result[:iterations]} iterations executed in #{result[:time].round 4} seconds"

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_nonblock
end

puts "  #call_nonblock: #{result[:iterations]} iterations executed in #{result[:time].round 4} seconds"

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_detached
end

puts "  #call_detached: #{result[:iterations]} iterations executed in #{result[:time].round 4} seconds"

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_and_forget
end

puts "#call_and_forget: #{result[:iterations]} iterations executed in #{result[:time].round 4} seconds"