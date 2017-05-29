module Concurrently
  class Proc
    # A general error for the failed the creation or evaluation of a concurrent
    # proc. It is only used if the error can not be attributed to an error in
    # the executed block of code of the proc itself.
    class Error < Concurrently::Error; end

    # An error indicating the evaluation of a concurrent proc has been
    # cancelled
    class CancelledError < Error; end

    # An error indicating the evaluation of a concurrent proc could not be
    # concluded in a given time frame
    class TimeoutError < CancelledError; end
  end
end