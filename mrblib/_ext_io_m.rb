class IO
  include(Kernel.dup.class_eval do
    (instance_methods - %i(hash)).each{ |m| remove_method m }
    self
  end)

  unless const_defined? :EAGAIN
    class EAGAIN < Exception; end
  end

  unless const_defined? :WaitReadable
    module WaitReadable; end
    class EAGAIN
      include WaitReadable
    end
  end

  unless const_defined? :WaitWritable
    module WaitWritable; end
    class EAGAIN
      include WaitWritable
    end
  end

  unless method_defined? :read_nonblock
    def read_nonblock(maxlen, outbuf = nil)
      if IO.select [self], nil, nil, 0
        sysread(maxlen, outbuf)
      else
        raise EAGAIN, 'Resource temporarily unavailable - read would block'
      end
    end
  end

  unless method_defined? :write_nonblock
    def write_nonblock(string)
      if IO.select nil, [self], nil, 0
        syswrite(string)
      else
        raise EAGAIN, 'Resource temporarily unavailable - write would block'
      end
    end
  end
end