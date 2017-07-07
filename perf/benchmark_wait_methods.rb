stage = Stage.new
batch_size = ARGV.fetch(0, 1).to_i
print_results_only = ARGV[1] == 'skip_header'

stage.benchmark :wait,
  batch_size: batch_size,
  proc: <<RUBY, call: :call
proc do
  wait 0 # schedule the proc be resumed ASAP
end
RUBY

stage.benchmark "await_readable",
  batch_size: batch_size,
  proc: <<RUBY, call: :call, args: <<RUBY
proc do |r,w|
  r.await_readable
end
RUBY
IO.pipe.tap{ |r,w| w.write '0' }
RUBY

stage.benchmark "await_writable",
  batch_size: batch_size,
  proc: <<RUBY, call: :call, args: <<RUBY
proc do |r,w|
  w.await_writable
end
RUBY
IO.pipe
RUBY

# Warm up
wait_proc = concurrent_proc{ wait 0 }
stage.execute{ wait_proc.call }

# Performance
stage.perform print_results_only