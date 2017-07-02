#!/bin/env ruby

require_relative "Ruby/stage"

stage = Stage.new

evaluation = Concurrently::Evaluation.current
conproc = concurrent_proc{ evaluation.resume! }

result = stage.__send__(ARGV[0] || :measure, seconds: 1) do
  conproc.call_detached
  await_resume!
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"