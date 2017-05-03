class IOEventLoop::WallClock
  def initialize
    @start_time = Time.now.to_f
  end

  def now
    Time.now.to_f - @start_time
  end
end