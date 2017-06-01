module Concurrently
  class Evaluation
    # A general error for a failed evaluation. It is only used if the error
    # can not be attributed to an error in the executed block of code of the
    # proc itself.
    class Error < Concurrently::Error; end

    # An error indicating an evaluation could not be concluded in a given
    # time frame
    class TimeoutError < Error; end
  end
end