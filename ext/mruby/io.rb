# @api mruby_patches
# @since 1.0.0
#
# mruby-io does not support non-blocking io operations.
class IO
  unless const_defined? :EAGAIN
    # raised if {IO#read_nonblock} or {IO#write_nonblock} would block
    class EAGAIN < Exception; end
  end

  unless const_defined? :WaitReadable
    # raised if IO#read_nonblock would block
    module WaitReadable; end
    class EAGAIN
      include WaitReadable
    end
  end

  unless const_defined? :WaitWritable
    # raised if IO#write_nonblock would block
    module WaitWritable; end
    class EAGAIN
      include WaitWritable
    end
  end

  unless method_defined? :read_nonblock
    # Implements IO#read_nonblock for mruby
    #
    # @see https://ruby-doc.org/core-1.9.3/IO.html#method-i-read_nonblock
    #   Ruby's documentation for IO#read_nonblock
    def read_nonblock(maxlen, outbuf = '')
      if IO.select [self], nil, nil, 0
        sysread(maxlen, outbuf)
      else
        raise EAGAIN, 'Resource temporarily unavailable - read would block'
      end
    end
  end

  unless method_defined? :write_nonblock
    # Implements IO#write_nonblock for mruby
    #
    # @see https://ruby-doc.org/core-1.9.3/IO.html#method-i-write_nonblock
    #   Ruby's documentation for `IO#write_nonblock`
    def write_nonblock(string)
      if IO.select nil, [self], nil, 0
        syswrite(string)
      else
        raise EAGAIN, 'Resource temporarily unavailable - write would block'
      end
    end
  end
end