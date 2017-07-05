stage = Stage.new

conproc = concurrent_proc do |r,w|
  begin
    r.read_nonblock 1
  rescue IO::WaitReadable
    w.write '0'
    r.await_readable
    retry
  end
end

r,w = IO.pipe

result = stage.profile(seconds: 1) do
  conproc.call r,w
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"