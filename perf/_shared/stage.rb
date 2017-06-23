require 'bundler'

Bundler.require :default
Bundler.require :perf

class Stage
  def measure(seconds: 1) # &test
    GC.start
    GC.disable
    profile = RubyProf::Profile.new(merge_fibers: true).tap(&:start) if ARGV[0] == 'profile'

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

    if ARGV[0] == 'profile'
      printer = ARGV[1].dup || 'flat'
      printer[0] = printer[0].capitalize
      RubyProf.const_get("#{printer}Printer").new(profile.stop).print(STDOUT, sort_method: :self_time)
    end
    GC.enable

    { iterations: iterations, time: (stop_time-start_time) }
  end
end

