#!/bin/env ruby

require_relative "_shared/stage"

stage = Stage.new

proc = proc{}
conproc = concurrent_proc{}

puts "proc = proc{}"
puts "conproc = concurrent_proc{}"
puts

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  proc.call
end
puts "proc.call:               #{result[:iterations]} iterations executed in #{result[:time].round 4} seconds"

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call
end

puts "conproc.call:            #{result[:iterations]}  iterations executed in #{result[:time].round 4} seconds"

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_nonblock
end

puts "conproc.call_nonblock:   #{result[:iterations]}  iterations executed in #{result[:time].round 4} seconds"

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_detached
end

puts "conproc.call_detached:   #{result[:iterations]}  iterations executed in #{result[:time].round 4} seconds"

result = stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_and_forget
end

puts "conproc.call_and_forget: #{result[:iterations]}  iterations executed in #{result[:time].round 4} seconds"