# @api ruby_patches
# @since 1.0.0
class Thread
  # Disable fiber-local variables and treat variables using the fiber-local
  # interface as thread-local. Most of the code out there is not using
  # fibers explicitly and really intends to attach values to the current
  # thread instead to the current fiber.
  #
  # This also makes sure we can safely reuse fibers without worrying about
  # lost or leaked fiber-local variables.

  # Redirect getting fiber locals to getting thread locals
  alias_method :[], :thread_variable_get

  # Redirect setting fiber locals to setting thread locals
  alias_method :[]=, :thread_variable_set

  # Redirect checking fiber local to checking thread local
  alias_method :key?, :thread_variable?

  # Redirect getting names for fiber locals to getting names of thread locals
  alias_method :keys, :thread_variables
end