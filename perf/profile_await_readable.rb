stage = Stage.new

conproc = concurrent_proc do
  r,w = IO.pipe
  begin
    r.read_nonblock 1
    r.close
  rescue IO::WaitReadable
    w.write '0'; w.close
    r.await_readable
    retry
  end
end

result = stage.profile(seconds: 1) do
  conproc.call
end

puts "#{result[:iterations]} executions in #{result[:time].round 4} seconds"