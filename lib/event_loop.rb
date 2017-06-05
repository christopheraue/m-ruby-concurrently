module Concurrently
  # @api ruby_patches
  # @since 1.0.0
  class EventLoop
    # Attach an event loop to every thread in Ruby.
    def self.current
      Thread.current.__concurrently_event_loop__
    end

    # Use hitimes for a faster calculation of time intervals.
    time_module = Module.new do
      def reinitialize!
        @clock = Hitimes::Interval.new.tap(&:start)
        super
      end

      def lifetime
        @clock.to_f
      end
    end

    prepend time_module
  end
end