stage = Stage.new

conproc = concurrent_proc{ wait 0 }

result = stage.profile(seconds: 1) do
  conproc.call
  wait 0
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"