#!/bin/env ruby

require_relative "_shared/stage"

stage = Stage.new

conproc = concurrent_proc{}

stage.measure(seconds: 1, profiler: RubyProf::FlatPrinter) do
  conproc.call_and_forget
end