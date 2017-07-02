require 'bundler'

Bundler.require :default
Bundler.require :perf

class Stage
  def gc_disabled
    GC.start
    GC.disable
    yield
  ensure
    GC.enable
  end

  def execute(seconds: 1)
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

  def measure(seconds: 1) # &test
    gc_disabled do
      execute(seconds: seconds){ yield }
    end
  end

  def profile(seconds: 1, printer: 'flat')
    gc_disabled do
      profile = RubyProf::Profile.new(merge_fibers: true).tap(&:start)

      result = execute(seconds: seconds){ yield }

      printer[0] = printer[0].capitalize
      RubyProf.const_get("#{printer}Printer").new(profile.stop).print(STDOUT, sort_method: :self_time)

      result
    end
  end
end

