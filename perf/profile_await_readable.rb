stage = Stage.new

r,w = IO.pipe
w.write '0'

result = stage.profile(seconds: 1) do
  r.await_readable
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"