# @private
# @since 1.0.0
class Thread
  # Attach an event loop to every thread in Ruby.
  def __concurrently_event_loop__
    @__concurrently_event_loop__ ||= Concurrently::EventLoop.new
  end
end