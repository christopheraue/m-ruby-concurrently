module Concurrently
  # Ruby has additional error classes
  RESCUABLE_ERRORS << NoMemoryError << SecurityError
end
