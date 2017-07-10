# @api public
#
# Concurrently adds a few methods to `IO` which make them available
# for every IO instance.
class IO
  # Suspends the current evaluation until IO is readable.
  #
  # While waiting, the code jumps to the event loop and executes other
  # evaluations that are ready to run in the meantime.
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
  # @example Waiting inside a concurrent evaluation
  #   # Control flow is indicated by (N)
  #
  #   r,w = IO.pipe
  #
  #   # (1)
  #   reader = concurrently do
  #     # (4)
  #     r.await_readable
  #     # (6)
  #     r.read
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
  #   reader.await_result # => 'Hey from the other proc!'
  #   # (7)
  #
  #   r.close
  #
  # @example Waiting outside a concurrent evaluation
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
  #   # => returns false after 0.1 seconds
  #
  # @since 1.0.0
  def await_readable(opts = {})
    io_selector = Concurrently::EventLoop.current.io_selector
    io_selector.await_reader(self, Concurrently::Evaluation.current)
    await_resume! opts
  ensure
    io_selector.cancel_reader(self)
  end

  # Waits until successfully read from IO with blocking other evaluations.
  #
  # If IO is not readable right now it blocks the current concurrent evaluation
  # and tries again after it became readable.
  #
  # This method is a shortcut for:
  #
  # ```
  # begin
  #   io.read_nonblock(maxlen, outbuf)
  # rescue IO::WaitReadable
  #   io.await_readable
  #   retry
  # end
  # ```
  #
  # @see https://ruby-doc.org/core/IO.html#method-i-read_nonblock
  #   Ruby documentation for `IO#read_nonblock` for details about parameters and return values.
  #
  # @example
  #   r,w = IO.pipe
  #   w.write "Hello!"
  #   r.await_read 1024 # => "Hello!"
  #
  # @overload await_read(maxlen)
  #   Reads maxlen bytes from IO and returns it as new string
  #
  #   @param [Integer] maxlen
  #   @return [String] read string
  #
  # @overload await_read(maxlen, outbuf)
  #   Reads maxlen bytes from IO and fills the given buffer with them.
  #
  #   @param [Integer] maxlen
  #   @param [String] outbuf
  #   @return [outbuf] outbuf filled with read string
  #
  # @since 1.1.0
  def await_read(maxlen, outbuf = nil)
    read_nonblock(maxlen, outbuf)
  rescue IO::WaitReadable
    await_readable
    retry
  end

  # Reads from IO concurrently.
  #
  # Reading is done in a concurrent evaluation in the background.
  #
  # This method is a shortcut for:
  #
  # ```
  # concurrently{ io.await_read(maxlen, outbuf) }
  # ```
  #
  # @see https://ruby-doc.org/core/IO.html#method-i-read_nonblock
  #   Ruby documentation for `IO#read_nonblock` for details about parameters and return values.
  #
  # @example
  #   r,w = IO.pipe
  #   w.write "Hello!"
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
  #
  # @since 1.0.0
  def concurrently_read(maxlen, outbuf = nil)
    READ_PROC.call_detached(self, maxlen, outbuf)
  end

  # @private
  READ_PROC = Concurrently::Proc.new do |io, maxlen, outbuf|
    io.await_read(maxlen, outbuf)
  end

  # Suspends the current evaluation until IO is writable.
  #
  # While waiting, the code jumps to the event loop and executes other
  # evaluations that are ready to run in the meantime.
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
  # @example Waiting inside a evaluation
  #   # Control flow is indicated by (N)
  #
  #   r,w = IO.pipe
  #
  #   # jam the pipe with x's, assuming the pipe's max capacity is 2^16 bytes
  #   w.write 'x'*65536
  #
  #   # (1)
  #   writer = concurrently do
  #     # (4)
  #     w.await_writable
  #     # (6)
  #     w.write 'I can write again!'
  #     :written
  #   end
  #
  #   # (2)
  #   concurrently do
  #     # (5)
  #     r.read 65536 # clear the pipe
  #   end
  #
  #   # (3)
  #   writer.await_result # => :written
  #   # (7)
  #
  #   r.close; w.close
  #
  # @example Waiting outside a evaluation
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
  #   # => returns false after 0.1 seconds
  #
  # @since 1.0.0
  def await_writable(opts = {})
    io_selector = Concurrently::EventLoop.current.io_selector
    io_selector.await_writer(self, Concurrently::Evaluation.current)
    await_resume! opts
  ensure
    io_selector.cancel_writer(self)
  end

  # Waits until successfully written to IO with blocking other evaluations.
  #
  # If IO is not writable right now it blocks the current evaluation
  # and tries again after it became writable.
  #
  # This methods is a shortcut for:
  #
  # ```
  # begin
  #   io.write_nonblock(string)
  # rescue IO::WaitWritable
  #   io.await_writable
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
  #   w.await_written "Hello!"
  #   r.read 1024 # => "Hello!"
  #
  # @since 1.1.0
  def await_written(string)
    write_nonblock(string)
  rescue IO::WaitWritable
    await_writable
    retry
  end

  # Writes to IO concurrently.
  #
  # Writing is done in a concurrent evaluation in the background.
  #
  # This method is a shortcut for:
  #
  # ```
  # concurrently{ io.await_written(string) }
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
  #   r.read 1024 # => "Hello!"
  #
  # @since 1.0.0
  def concurrently_write(string)
    WRITE_PROC.call_detached(self, string)
  end

  # @private
  WRITE_PROC = Concurrently::Proc.new do |io, string|
    io.await_written(string)
  end
end