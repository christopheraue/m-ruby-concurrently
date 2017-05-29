# Concurrently adds a few methods to "IO" which make them available
# for every IO instance.
#
# This is part of the main API of Concurrently.
#
# @api public
class IO
  # Suspends the current concurrent proc or fiber until IO is readable
  def await_readable(opts = {})
    io_watcher = Concurrently::EventLoop.current.io_watcher
    fiber = Fiber.current
    io_watcher.await_reader(self, fiber)
    await_scheduled_resume! opts
  ensure
    io_watcher.cancel_reader(self)
  end

  # Suspends the current concurrent proc or fiber until IO is writable
  def await_writable(opts = {})
    io_watcher = Concurrently::EventLoop.current.io_watcher
    fiber = Fiber.current
    io_watcher.await_writer(self, fiber)
    await_scheduled_resume! opts
  ensure
    io_watcher.cancel_writer(self)
  end
end