assert "IO#await_readable" do
  r,w = IO.pipe

  concurrently do
    w.write "test"
  end

  assert_equal r.await_readable, true
  assert_equal r.read(4), "test"
end

assert "IO#await_writable" do
  r,w = IO.pipe

  w.write ' '*(2**16) # jam the pipe

  concurrently do
    r.read 2**16 # clear the pipe
  end

  assert_equal w.await_writable, true
end