class Fiber
  def yield_to_event_loop!
    Concurrently::EventLoop.current.fiber.resume
  end

  def resume_from_event_loop!(result = nil)
    Fiber.yield result # yields to the fiber from the event loop
  end

  def schedule_resume!(result = nil)
    Concurrently::EventLoop.current.run_queue.schedule_immediately(self, result)
  end
end