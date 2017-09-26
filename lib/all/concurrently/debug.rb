module Concurrently
  # @api public
  # @since 1.2.0
  #
  # `Concurrently::Debug` offers an interface to configure functionality
  # being helpful while debugging applications build with Concurrently.
  module Debug
    @overwrites = []

    class << self
      # @private
      # Defines blocks of code to evaluate once debugging is enabled. Used
      # internally only.
      #
      # @param klass The class in whose scope the given block will be evaluated
      #              with `#class_eval`
      # @param block The block of code to evaluate
      def overwrite(klass, &block)
        @overwrites << proc{ klass.class_eval &block }
      end

      # Enables debugging
      def enable
        @overwrites.each{ |overwrite| overwrite.call }
      end
    end
  end
end