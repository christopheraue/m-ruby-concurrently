module Concurrently
  # @api public
  # @since 1.2.0
  #
  # `Concurrently::Debug` offers an interface to configure functionality
  # being helpful while debugging applications build with Concurrently.
  #
  # Enabling debugging logs the locations concurrent procs are entered,
  # suspended, resumed and left at. With its help the path an application takes
  # through all concurrent procs can be traced.
  module Debug
    @overwrites = []
    @fibers = {}

    class << self
      # Enables debugging
      #
      # @param [Logger] logger
      # @param [Array<String>] filter An array of strings to filter
      #   stacktrace locations by. The first location in a stacktrace
      #   containing one of the given strings will be used in the log message.
      #   If no filter is given, the first location is logged.
      # @return [true]
      #
      # @example
      #   require 'logger'
      #   Concurrently::Debug.enable Logger.new(STDOUT), ['file2']
      #
      #   # Assuming the stacktrace when resuming/suspending looks like:
      #   #   /path/to/file1.rb
      #   #   /path/to/file2.rb
      #   #   /path/to/file3.rb
      #   #
      #   # Then, the logged location will be /path/to/file2.rb
      def enable(logger, filter = nil)
        @logger = logger
        @filter = filter
        @overwrites.each{ |overwrite| overwrite.call }
        true
      end

      # @private
      #
      # Defines blocks of code to evaluate once debugging is enabled. Used
      # internally only.
      #
      # @param [Class] klass The class in whose scope the given block will be evaluated
      #                      with `#class_eval`
      # @param [Proc] block The block of code to evaluate
      def overwrite(klass, &block)
        @overwrites << proc{ klass.class_eval &block }
      end

      # @private
      def log_begin(fiber, location)
        return unless @logger
        return unless @filter.any?{ |match| location.include? match }

        @fibers[fiber.__id__] = location
        @logger.debug ".---- BEGIN #{location}"
      end

      # @private
      def log_suspend(fiber, locations)
        return unless @logger
        return unless @fibers.key? fiber.__id__

        location = if @filter
                     locations.find{ |loc| @filter.any?{ |match| loc.include? match } }
                   else
                     locations.first
                   end
        @logger.debug "'-> SUSPEND #{location}"
      end

      # @private
      def log_resume(fiber, locations)
        return unless @logger
        return unless @fibers.key? fiber.__id__

        location = if @filter
                     locations.find{ |loc| @filter.any?{ |match| loc.include? match } }
                   else
                     locations.first
                   end
        @logger.debug ".--- RESUME #{location}"
      end

      # @private
      def log_end(fiber)
        return unless @logger
        return unless location = @fibers.delete(fiber.__id__)
        @logger.debug "'-----> END #{location}"
      end

      # @private
      def log_cancel(fiber)
        return unless @logger
        return unless location = @fibers.delete(fiber.__id__)
        @logger.debug "'--> CANCEL #{location}"
      end

      # @private
      def log_error(fiber)
        return unless @logger
        return unless location = @fibers.delete(fiber.__id__)
        @logger.debug "'---> ERROR #{location}"
      end
    end
  end
end