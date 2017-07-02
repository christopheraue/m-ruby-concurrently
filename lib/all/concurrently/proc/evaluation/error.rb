module Concurrently
  class Proc::Evaluation
    class Cancelled < Exception
      # should not be rescued accidentally and therefore is an exception
    end

    module RescueableError
      [ScriptError, StandardError, SystemStackError].each do |error_class|
        append_features error_class
      end
    end
  end
end