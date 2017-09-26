module Concurrently
  # @api public
  # @since 1.1.2
  #
  # The `Concurrently::Logger` logs the locations a concurrent proc is entered,
  # suspended, resumed and left at. With its help the path an application takes
  # through all concurrent procs can be traced.
  #
  # Logging is deactivated, by default. It is activated by setting {#logger=}.
  class Logger
    # The logger that is currently active for the current thread.
    #
    # This method is thread safe. Each thread returns its own logger.
    #
    # @return [Logger]
    #
    # @example
    #   Concurrently::Logger.current # => #<Concurrently::Logger:0x00000000e5be10>
    def self.current
      @current ||= new
    end

    # @private
    def initialize
      @fibers = {}
    end

    # @!attribute [w] logger
    #
    # Sets the logger.
    #
    # @param [::Logger] value
    # @return [::Logger]
    #
    # @example
    #   require 'logger'
    #   Concurrently::Logger.current.logger = Logger.new(STDOUT)
    attr_writer :logger

    # @!attribute [w] locations
    #
    # Sets an array of strings to filter stacktrace locations by. The first
    # stacktrace location containing one of the given strings will be used
    # in the log message. By default, the first location is logged.
    #
    # @param [Array<String>] value
    # @return [Array<String>]
    #
    # @example
    #   Concurrently::Logger.current.locations = ['loc2']
    #
    #   # Assuming the stacktrace when resuming/suspending looks like:
    #   #   /path/to/loc1/file.rb
    #   #   /path/to/loc2/file.rb
    #   #   /path/to/loc3/file.rb
    #   #
    #   # Then, the logged location will be /path/to/loc2/file.rb
    attr_writer :locations

    def active?
      !!@logger
    end

    # @private
    def log_begin(fiber, location)
      return unless @logger
      return unless @locations.any?{ |match| location.include? match }

      @fibers[fiber.__id__] = location
      @logger.debug ".---- BEGIN #{location}"
    end

    # @private
    def log_suspend(fiber, locations)
      return unless @logger
      return unless @fibers.key? fiber.__id__

      location = if @locations
                   locations.find{ |loc| @locations.any?{ |match| loc.include? match } }
                 else
                   locations.first
                 end
      @logger.debug "'-> SUSPEND #{location}"
    end

    # @private
    def log_resume(fiber, locations)
      return unless @logger
      return unless @fibers.key? fiber.__id__

      location = if @locations
                   locations.find{ |loc| @locations.any?{ |match| loc.include? match } }
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