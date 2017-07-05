stage = Stage.new
batch_size = ARGV.fetch(0, 1).to_i
print_results_only = ARGV[1] == 'skip_header'

conproc = <<RUBY
concurrent_proc do
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
RUBY

stage.benchmark :call,
  batch_size: batch_size,
  proc: conproc,
  call: :call,
  sync: true

stage.benchmark :call_nonblock,
  batch_size: batch_size,
  proc: conproc,
  call: :call_nonblock,
  sync: true

stage.benchmark :call_detached,
  batch_size: batch_size,
  proc: conproc,
  call: :call_detached,
  sync: true

stage.benchmark :call_and_forget,
  batch_size: batch_size,
  proc: conproc,
  call: :call_and_forget,
  sync: true

stage.perform print_results_only