stage = Stage.new
batch_size = ARGV.fetch(0, 1).to_i
print_results_only = ARGV[1] == 'skip_header'

stage.benchmark :waiter,
  batch_size: batch_size,
  proc: "concurrent_proc{ wait 0 }",
  call: :call_detached,
  sync: true

stage.benchmark :reader,
  batch_size: batch_size,
  proc: <<RUBY, call: :call_detached, args: <<RUBY, sync: true
concurrent_proc do |r,w,chunk|
  begin
    r.read_nonblock chunk.size
  rescue IO::WaitReadable
    w.write chunk
    r.await_readable
    retry
  end
end
RUBY
r,w = IO.pipe
chunk = '0'
[r,w,chunk]
RUBY

stage.benchmark :writer,
  batch_size: batch_size,
  proc: <<RUBY, call: :call_detached, args: <<RUBY, sync: true
concurrent_proc do |r,w,chunk|
  begin
    w.write_nonblock chunk
  rescue IO::WaitWritable
    r.read chunk.size
    w.await_writable
    retry
  end
end
RUBY
r,w = IO.pipe
chunk = '0'*4096
w.write '0'*65536 # jam pipe
[r,w,chunk]
RUBY

stage.perform print_results_only