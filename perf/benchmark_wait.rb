stage = Stage.new
batch_size = ARGV.fetch(0, 1).to_i
print_results_only = ARGV[1] == 'skip_header'

stage.benchmark :call,
  batch_size: batch_size,
  proc: "concurrent_proc{ wait 0 }",
  call: :call,
  sync: true

stage.benchmark :call_nonblock,
  batch_size: batch_size,
  proc: "concurrent_proc{ wait 0 }",
  call: :call_nonblock,
  sync: true

stage.benchmark :call_detached,
  batch_size: batch_size,
  proc: "concurrent_proc{ wait 0 }",
  call: :call_detached,
  sync: true

stage.benchmark :call_and_forget,
  batch_size: batch_size,
  proc: "concurrent_proc{ wait 0 }",
  call: :call_and_forget,
  sync: true

stage.perform print_results_only