require 'bundler'

Bundler.require :default
Bundler.require :perf

class Stage
  def measure(seconds: 1, profiler: nil) # &test
    profile = RubyProf::Profile.new(merge_fibers: true).tap(&:start) if ARGV[0] == 'profile'

    event_loop = Concurrently::EventLoop.current
    iterations = 0
    start_time = event_loop.lifetime
    end_time = start_time + seconds
    while event_loop.lifetime < end_time
      iterations += 1
      yield
    end
    stop_time = event_loop.lifetime

    profiler.new(profile.stop).print(STDOUT, sort_method: :self_time) if ARGV[0] == 'profile'

    { iterations: iterations, time: (stop_time-start_time) }
  end
end

