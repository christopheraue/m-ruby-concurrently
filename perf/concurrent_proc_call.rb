#!/bin/env ruby

require_relative "_shared/stage"

stage = Stage.new

conproc = concurrent_proc{}

result = stage.measure(seconds: 1) do
  conproc.call
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"