module Concurrently
  # @api public
  # @since 1.2.0
  #
  # With `Concurrently::Debug` the locations where concurrent procs are
  # entered, suspended, resumed and exited at can be logged. The log shows
  # the subsequent order in which concurrent procs are executed.
  #
  # It looks like:
  #
  #     .---- BEGIN 94khk test/CRuby/event_loop_spec.rb:16
  #     '-> SUSPEND 94khk lib/all/concurrently/proc/evaluation.rb:86:in `__suspend__'
  #     ... [other entries] ...
  #     .--- RESUME 94khk lib/all/concurrently/proc/evaluation.rb:86:in `__suspend__'
  #     '-----> END 94khk test/CRuby/event_loop_spec.rb:16
  #
  # This log section indicates that the concurrent proc defined at
  # `test/CRuby/event_loop_spec.rb:16` has been started to be evaluated. It is
  # assigned the id `94khk`. The code of the proc is evaluated until it is
  # suspended at `lib/all/concurrently/proc/evaluation.rb:86`. After other
  # concurrent procs where scheduled to run, proc `94khk` is resumed again and
  # from there on is evaluated until its end.
  #
  # Next to `END`, there are two other variations how the evaluation of a
  # concurrent proc can be marked as concluded. These are
  # * `CANCEL` if the evaluation is prematurely concluded with
  #   {Proc::Evaluation#conclude_to} and
  # * `ERROR` if the evaluation raises an error.
  #
  # The id of an evaluation may (and very likely will) be reused after the
  # evaluation was concluded.
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
        return if @filter and not @filter.any?{ |match| location.include? match }

        @fibers[fiber.__id__] = location
        @logger.debug ".---- BEGIN #{fiber.__id__.to_s 36} #{location}"
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
        @logger.debug "'-> SUSPEND #{fiber.__id__.to_s 36} #{location}"
      end

      # @private
      def log_schedule(fiber, locations)
        return unless @logger

        location = if @filter
                     locations.find{ |loc| @filter.any?{ |match| loc.include? match } }
                   else
                     locations.first
                   end

        return unless location

        prefix = (@fibers.key? Fiber.current.__id__) ? '|' : ' '
        @logger.debug "#{prefix}  SCHEDULE #{fiber.__id__.to_s 36} from #{location}"
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
        @logger.debug ".--- RESUME #{fiber.__id__.to_s 36} #{location}"
      end

      # @private
      def log_end(fiber)
        return unless @logger
        return unless location = @fibers.delete(fiber.__id__)
        @logger.debug "'-----> END #{fiber.__id__.to_s 36} #{location}"
      end

      # @private
      def log_cancel(fiber)
        return unless @logger
        return unless location = @fibers.delete(fiber.__id__)
        @logger.debug "'--> CANCEL #{fiber.__id__.to_s 36} #{location}"
      end

      # @private
      def log_error(fiber)
        return unless @logger
        return unless location = @fibers.delete(fiber.__id__)
        @logger.debug "'---> ERROR #{fiber.__id__.to_s 36} #{location}"
      end
    end
  end
end