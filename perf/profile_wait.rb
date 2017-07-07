stage = Stage.new

result = stage.profile(seconds: 1) do
  wait 0
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"