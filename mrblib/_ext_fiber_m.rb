class Fiber
  # mruby does not allow instance variables for fibers. To get something
  # similar we have to jump through some hoops.

  alias_method :original_initialize, :initialize

  def initialize
    ivars = {}
    define_singleton_method(:ivars) { ivars }
    original_initialize{ |*args| yield *args }
  end
end