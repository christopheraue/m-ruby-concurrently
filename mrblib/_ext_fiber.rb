Fiber.current # let mruby created the root fiber with the correct class

class Fiber
  def resume_from_event_loop!(result = nil)
    Fiber.yield result # yields to the fiber from the event loop
  end

  # @api private
  DEFAULT_RESUME_OPTS = { deferred_only: true }.freeze

  # @api public
  # Schedules the fiber to be resumed
  def schedule_resume!(result = nil)
    run_queue = Concurrently::EventLoop.current.run_queue

    # Cancel running the fiber if it has already been scheduled to run; but
    # only if it was scheduled with a time offset. This is used to cancel the
    # timeout of a wait operation if the waiting fiber is resume before the
    # timeout is triggered.
    run_queue.cancel(self, DEFAULT_RESUME_OPTS)

    run_queue.schedule_immediately(self, result)
  end
end