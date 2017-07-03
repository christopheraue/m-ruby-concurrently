require 'bundler'

Bundler.require :default
Bundler.require :perf

require_relative '../stage'

class Stage
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

