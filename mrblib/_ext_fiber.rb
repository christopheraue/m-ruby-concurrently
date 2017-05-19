class Fiber
  def yield_to_event_loop!
    Concurrently::EventLoop.current.start
  end

  def send_to_foreground!(result = nil)
    Fiber.yield result # yields to the fiber from the event loop
  end

  def manually_resume!(result = nil)
    Concurrently::EventLoop.current.manually_resume!(self, result)
  end
end