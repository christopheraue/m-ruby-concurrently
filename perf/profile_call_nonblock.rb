stage = Stage.new

conproc = concurrent_proc{}

result = stage.profile(seconds: 1) do
  conproc.call_nonblock
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"