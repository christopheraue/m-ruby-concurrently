stage = Stage.new
format = "  %-25s %7d executions in %2.4f seconds"

factor = ARGV.fetch(0, 1).to_i
skip_header = ARGV[1] == 'skip_header'

puts <<-DOC unless skip_header
Benchmarked Code
----------------
  conproc = concurrent_proc{ wait 0 }
  
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

conproc = concurrent_proc{ wait 0 }

result = stage.measure(seconds: 1) do
  factor.times{ conproc.call }
  # no need to enter the event loop manually. It already happens in #call
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