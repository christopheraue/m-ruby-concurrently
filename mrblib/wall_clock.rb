module IOEventLoop
  module WallClock
    @start_time = Time.now.to_f
  end

  class << WallClock
    def now
      Time.now.to_f - @start_time
    end
  end
end