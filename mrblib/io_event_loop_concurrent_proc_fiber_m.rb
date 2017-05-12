class IOEventLoop
  class ConcurrentProcFiber
    def loop=(loop)
      ivars[:loop] = loop
    end

    def future=(future)
      ivars[:future] = future
    end

    def loop
      ivars[:loop]
    end

    def future
      ivars[:future]
    end
  end
end