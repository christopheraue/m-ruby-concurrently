class Stage
  def gc_disabled
    GC.start
    GC.disable
    yield
  ensure
    GC.enable
  end

  def execute(opts = {})
    seconds = opts[:seconds] || 1
    event_loop = Concurrently::EventLoop.current
    event_loop.reinitialize!
    iterations = 0
    start_time = event_loop.lifetime
    end_time = start_time + seconds
    while event_loop.lifetime < end_time
      yield
      iterations += 1
    end
    stop_time = event_loop.lifetime
    { iterations: iterations, time: (stop_time-start_time) }
  end

  def measure(opts = {}) # &test
    gc_disabled do
      execute(opts){ yield }
    end
  end
end
