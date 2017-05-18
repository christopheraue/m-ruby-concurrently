class Thread
  def __concurrently_event_loop__
    @__concurrently_event_loop__ ||= Concurrently::EventLoop.new
  end
end