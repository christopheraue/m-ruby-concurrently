stage = Stage.new
batch_size = ARGV.fetch(0, 1).to_i
print_results_only = ARGV[1] == 'skip_header'

stage.benchmark :call,
  batch_size: batch_size,
  proc: "proc{}",
  call: :call

stage.benchmark :call,
  batch_size: batch_size,
  proc: "concurrent_proc{}",
  call: :call

stage.benchmark :call_nonblock,
  batch_size: batch_size,
  proc: "concurrent_proc{}",
  call: :call_nonblock

stage.benchmark :call_detached,
  batch_size: batch_size,
  proc: "concurrent_proc{}",
  call: :call_detached

stage.benchmark :call_and_forget,
  batch_size: batch_size,
  proc: "concurrent_proc{}",
  call: :call_and_forget

stage.perform print_results_only