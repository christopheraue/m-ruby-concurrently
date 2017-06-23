module Concurrently
  # @api public
  # @since 1.0.0
  #
  # The general error of this gem.
  class Error < StandardError; end

  # @private
  RESCUABLE_ERRORS = [ScriptError, StandardError, SystemStackError]
end
