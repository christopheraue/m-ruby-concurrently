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
  # @return [true]
  #
  # @example Waiting inside a concurrent proc
  #   # Control flow is indicated by (N)
  #
  #   r,w = IO.pipe
  #
  #   # (1)
  #   wait_proc = concurrent_proc do
  #      # (4)
  #      r.await_readable
  #      # (6)
  #      r.read
  #   end
  #
  #   # (2)
  #   concurrently do
  #     # (5)
  #     w.write 'Hey from the other proc!'
  #     w.close
  #   end
  #
  #   # (3)
  #   wait_proc.call # => 'Hey from the other proc!'
  #   # (7)
  #
  #   r.close
  #
  # @example Waiting outside a concurrent proc
  #   # Control flow is indicated by (N)
  #
  #   r,w = IO.pipe
  #
  #   # (1)
  #   concurrently do
  #     # (3)
  #     puts "I'm running while the outside is waiting!"
  #     w.write "Continue!"
  #     w.close
  #   end
  #
  #   # (2)
  #   r.await_readable
  #   # (4)
  #   r.read # => "Continue!"
  #
  #   r.close
  def await_readable(opts = {})
    io_watcher = Concurrently::EventLoop.current.io_watcher
    fiber = Fiber.current
    io_watcher.await_reader(self, fiber)
    await_scheduled_resume! opts
  ensure
    io_watcher.cancel_reader(self)
  end

  # Suspends the current concurrent proc until IO is writable. It can also be
  # used outside of concurrent procs.
  #
  # While waiting, the code jumps to the event loop and executes other
  # concurrent procs that are ready to run in the meantime.
  #
  # @return [true]
  #
  # @example Waiting inside a concurrent proc
  #   # Control flow is indicated by (N)
  #
  #   r,w = IO.pipe
  #
  #   # jam the pipe with x's, assuming the pipe's max capacity is 2^16 bytes
  #   w.write 'x'*65536
  #
  #   # (1)
  #   wait_proc = concurrent_proc do
  #      # (4)
  #      w.await_writable
  #      # (6)
  #      w.write 'I can write again!'
  #      :written
  #   end
  #
  #   # (2)
  #   concurrently do
  #     # (5)
  #     r.read 65536 # clear the pipe
  #   end
  #
  #   # (3)
  #   wait_proc.call # => :written
  #   # (7)
  #
  #   r.close; w.close
  #
  # @example Waiting outside a concurrent proc
  #   # Control flow is indicated by (N)
  #
  #   r,w = IO.pipe
  #
  #   # jam the pipe with x's, assuming the pipe's max capacity is 2^16 bytes
  #   w.write 'x'*65536
  #
  #   # (1)
  #   concurrently do
  #     # (3)
  #     puts "I'm running while the outside is waiting!"
  #     r.read 65536 # clear the pipe
  #   end
  #
  #   # (2)
  #   w.await_writable
  #   # (4)
  #
  #   r.close; w.close
  def await_writable(opts = {})
    io_watcher = Concurrently::EventLoop.current.io_watcher
    fiber = Fiber.current
    io_watcher.await_writer(self, fiber)
    await_scheduled_resume! opts
  ensure
    io_watcher.cancel_writer(self)
  end
end