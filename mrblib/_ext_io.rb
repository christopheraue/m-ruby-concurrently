# Concurrently adds a few methods to `IO` which make them available
# for every IO instance.
#
# @api public
class IO
  # Suspends the current evaluation until IO is readable. It can be used inside
  # and outside of concurrent procs.
  #
  # While waiting, the code jumps to the event loop and executes other
  # concurrent procs that are ready to run in the meantime.
  #
  # @param [Hash] opts
  # @option opts [Numeric] :within maximum time to wait *(defaults to: Float::INFINITY)*
  # @option opts [Object] :timeout_result result to return in case of an exceeded
  #   waiting time *(defaults to raising {Concurrently::Evaluation::TimeoutError})*
  #
  # @return [true]
  # @raise [Concurrently::Evaluation::TimeoutError] if a given maximum waiting time
  #   is exceeded and no custom timeout result is given.
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
  #
  # @example Waiting with a timeout
  #   r,w = IO.pipe
  #   r.await_readable(within: 1)
  #   # => raises a TimeoutError after 1 second
  #
  # @example Waiting with a timeout and a timeout result
  #   r,w = IO.pipe
  #   r.await_readable(within: 0.1, timeout_result: false)
  #   # => returns false after 0.1 second
  def await_readable(opts = {})
    io_selector = Concurrently::EventLoop.current.io_selector
    io_selector.await_reader(self, Concurrently::Evaluation.current)
    await_resume! opts
  ensure
    io_selector.cancel_reader(self)
  end

  # Reads from IO concurrently.
  #
  # If IO is not readable at the moment it blocks the current concurrent proc
  # and tries again after it got readable again. This is a shortcut for:
  #
  # ```
  # result = begin
  #   read_nonblock(maxlen, buf)
  # rescue IO::WaitReadable
  #   await_readable
  #   retry
  # end
  # ```
  #
  # @see https://ruby-doc.org/core/IO.html#method-i-read_nonblock
  #   Ruby documentation for `IO#read_nonblock` for details about parameters and return values.
  #
  # @example
  #   r,w = IO.pipe
  #   w.concurrently_write "Hello!"
  #   r.concurrently_read 1024 # => "Hello!"
  #
  # @overload concurrently_read(maxlen)
  #   Reads maxlen bytes from IO and returns it as new string
  #
  #   @param [Integer] maxlen
  #   @return [String] read string
  #
  # @overload concurrently_read(maxlen, outbuf)
  #   Reads maxlen bytes from IO and fills the given buffer with them.
  #
  #   @param [Integer] maxlen
  #   @param [String] outbuf
  #   @return [outbuf] outbuf filled with read string
  def concurrently_read(maxlen, outbuf = nil)
    read_nonblock(maxlen, outbuf)
  rescue IO::WaitReadable
    await_readable
    retry
  end

  # Suspends the current evaluation until IO is writable. It can be used inside
  # and outside of concurrent procs.
  #
  # While waiting, the code jumps to the event loop and executes other
  # concurrent procs that are ready to run in the meantime.
  #
  # @param [Hash] opts
  # @option opts [Numeric] :within maximum time to wait *(defaults to: Float::INFINITY)*
  # @option opts [Object] :timeout_result result to return in case of an exceeded
  #   waiting time *(defaults to raising {Concurrently::Evaluation::TimeoutError})*
  #
  # @return [true]
  # @raise [Concurrently::Evaluation::TimeoutError] if a given maximum waiting time
  #   is exceeded and no custom timeout result is given.
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
  #
  # @example Waiting with a timeout
  #   r,w = IO.pipe
  #   # jam the pipe with x's, assuming the pipe's max capacity is 2^16 bytes
  #   w.write 'x'*65536
  #
  #   w.await_writable(within: 1)
  #   # => raises a TimeoutError after 1 second
  #
  # @example Waiting with a timeout and a timeout result
  #   r,w = IO.pipe
  #   # jam the pipe with x's, assuming the pipe's max capacity is 2^16 bytes
  #   w.write 'x'*65536
  #
  #   w.await_writable(within: 0.1, timeout_result: false)
  #   # => returns false after 0.1 second
  def await_writable(opts = {})
    io_selector = Concurrently::EventLoop.current.io_selector
    io_selector.await_writer(self, Concurrently::Evaluation.current)
    await_resume! opts
  ensure
    io_selector.cancel_writer(self)
  end

  # Writes to IO concurrently.
  #
  # If IO is not writable at the moment it blocks the current concurrent proc
  # and tries again after it got writable again. This is a shortcut for:
  #
  # ```
  # result = begin
  #   write_nonblock(string)
  # rescue IO::WaitWritable
  #   await_writable
  #   retry
  # end
  # ```
  #
  # @param [String] string to write
  # @return [Integer] bytes written
  #
  # @see https://ruby-doc.org/core/IO.html#method-i-write_nonblock
  #   Ruby documentation for `IO#write_nonblock` for details about parameters and return values.
  #
  # @example
  #   r,w = IO.pipe
  #   w.concurrently_write "Hello!"
  #   r.concurrently_read 1024 # => "Hello!"
  def concurrently_write(string)
    write_nonblock(string)
  rescue IO::WaitWritable
    await_writable
    retry
  end
end