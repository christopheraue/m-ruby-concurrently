# Concurrently adds a few methods to "IO" which make them available
# for every IO instance.
#
# This is part of the main API of Concurrently.
#
# @api public
class IO
  # Suspends the current concurrent proc until IO is readable. It can also be
  # used outside of concurrent procs.
  #
  # While waiting, the code jumps to the event loop and executes other
  # concurrent procs that are ready to run in the meantime.
  #
  # @example Waiting inside a concurrent proc
  #   r,w = IO.pipe
  #
  #   wait_proc = concurrent_proc do
  #      r.await_readable
  #      r.read 24 # 'Hey from the other proc!' has 24 bytes
  #   end
  #
  #   concurrently do
  #     w.write 'Hey from the other proc!'
  #   end
  #
  #   wait_proc.call # => 'Hey from the other proc!'
  #
  #   r.close; w.close
  #
  # @example Waiting outside a concurrent proc
  #   r,w = IO.pipe
  #
  #   concurrently do
  #     puts "I'm running while the outside is waiting!"
  #     w.write "Continue!"
  #   end
  #
  #   r.await_readable
  #
  #   # prints: "I'm running while the outside is waiting!"
  #   # then continues since r is readable again
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