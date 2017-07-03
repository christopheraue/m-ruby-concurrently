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
      while n > 0
        res.unshift pop_single
        n -= 1
      end
      res
    else
      pop_single
    end
  end
end