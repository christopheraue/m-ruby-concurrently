class Thread
  # @api ruby_patches
  # @since 1.0.0
  #
  # Attach an event loop to every thread in Ruby.
  def __concurrently_event_loop__
    @__concurrently_event_loop__ ||= Concurrently::EventLoop.new
  end
end