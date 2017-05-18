class IO
  def await_readable(opts = {})
    Concurrently::EventLoop.current.await_readable(self, opts)
  end

  def await_writable(opts = {})
    Concurrently::EventLoop.current.await_writable(self, opts)
  end
end