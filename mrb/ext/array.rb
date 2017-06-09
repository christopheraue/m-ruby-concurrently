# @api mruby_patches
# @since 1.0.0
class Array
  # Alias for original Array#pop
  alias_method :pop_single, :pop

  # Reimplements Array#pop to add support for popping multiple items at once.
  #
  # By default, Array#pop can only pop a single item in mruby
  def pop(n = nil)
    if n
      res = []
      n.times{ res << pop_single }
      res.reverse!
    else
      pop_single
    end
  end
end