stage = Stage.new
format = "  %-25s %7d executions in %2.4f seconds"

skip_header = ARGV[1] == 'skip_header'

puts <<-DOC unless skip_header
Benchmarked Code
----------------
  proc = proc{}
  conproc = concurrent_proc{}
  
  while elapsed_seconds < 1
    #CALL#
  end
DOC

result_header = "Results for #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}"
puts <<-DOC

#{result_header}
#{'-'*result_header.length}
  #CALL#
DOC

proc = proc{}
conproc = concurrent_proc{}

result = stage.measure(seconds: 1) do
  proc.call
end
puts sprintf(format, "proc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call
end
puts sprintf(format, "conproc.call:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call_nonblock
end
puts sprintf(format, "conproc.call_nonblock:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call_detached
end
puts sprintf(format, "conproc.call_detached:", result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  conproc.call_and_forget
end
puts sprintf(format, "conproc.call_and_forget:", result[:iterations], result[:time])