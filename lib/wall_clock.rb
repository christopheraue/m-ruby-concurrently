module IOEventLoop::WallClock
  @clock = Hitimes::Interval.new.tap(&:start)
end

class << IOEventLoop::WallClock
  def now
    @clock.to_f
  end
end