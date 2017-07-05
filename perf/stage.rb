class Stage
  def initialize
    @benchmarks = []
  end

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

  def benchmark(*args)
    @benchmarks << Benchmark.new(self, *args)
  end

  def perform(print_results_only = false)
    if @benchmarks.size
      unless print_results_only
        puts Benchmark.header
        @benchmarks.each do |b|
          puts b.desc
        end
      end
      puts Benchmark.result_header
      @benchmarks.each{ |b| b.run }
      puts
    end
  end
end

