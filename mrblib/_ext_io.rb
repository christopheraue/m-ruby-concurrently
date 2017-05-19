class IO
  def await_readable(opts = {})
    io_watcher = Concurrently::EventLoop.current.io_watcher
    fiber = Fiber.current
    io_watcher.await_reader(self, fiber)
    await_manual_resume! opts
  ensure
    io_watcher.cancel_reader(self)
  end

  def await_writable(opts = {})
    io_watcher = Concurrently::EventLoop.current.io_watcher
    fiber = Fiber.current
    io_watcher.await_writer(self, fiber)
    await_manual_resume! opts
  ensure
    io_watcher.cancel_writer(self)
  end
end