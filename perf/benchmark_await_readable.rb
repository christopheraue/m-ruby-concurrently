stage = Stage.new
format = "  %-25s %7d executions in %2.4f seconds"

factor = ARGV.fetch(0, 1).to_i
skip_header = ARGV[1] == 'skip_header'

puts <<-DOC unless skip_header
Benchmarked Code
----------------
  r,w = IO.pipe
  
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
  
  while elapsed_seconds < 1
    #{factor}.times{ # CODE # }
    wait 0 # to enter the event loop
  end
DOC

result_header = "Results for #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}"
puts <<-DOC

#{result_header}
#{'-'*result_header.length}
  # CODE #
DOC

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

result = stage.measure(seconds: 1) do
  factor.times{ conproc.call }
  wait 0
end
puts sprintf(format, "conproc.call:", factor*result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  factor.times{ conproc.call_nonblock }
  wait 0
end
puts sprintf(format, "conproc.call_nonblock:", factor*result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  factor.times{ conproc.call_detached }
  wait 0
end
puts sprintf(format, "conproc.call_detached:", factor*result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  factor.times{ conproc.call_and_forget }
  wait 0
end
puts sprintf(format, "conproc.call_and_forget:", factor*result[:iterations], result[:time])