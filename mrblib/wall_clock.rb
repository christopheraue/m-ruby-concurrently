module IOEventLoop::WallClock
  @start_time = Time.now.to_f
end

class << IOEventLoop::WallClock
  def now
    Time.now.to_f - @start_time
  end
end