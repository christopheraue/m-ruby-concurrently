module Concurrently
  class Proc
    class Error < Concurrently::Error; end
    class CancelledError < Error; end
    class TimeoutError < CancelledError; end
  end
end