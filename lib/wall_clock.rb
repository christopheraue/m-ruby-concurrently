class IOEventLoop::WallClock
  def initialize
    @clock = Hitimes::Interval.new.tap(&:start)
  end

  def now
    @clock.to_f
  end
end