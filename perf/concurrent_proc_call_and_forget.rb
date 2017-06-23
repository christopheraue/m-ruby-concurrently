#!/bin/env ruby

require_relative "_shared/stage"

stage = Stage.new

evaluation = Concurrently::Evaluation.current
conproc = concurrent_proc{ evaluation.resume! }

result = stage.measure(seconds: 1) do
  conproc.call_and_forget
  await_resume!
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"