# @api mruby_patches
# @since 1.0.0
class Array
  unless method_defined? :bsearch_index
    # Implements Array#bsearch_index for mruby.
    def bsearch_index
      # adapted from https://github.com/python-git/python/blob/7e145963cd67c357fcc2e0c6aca19bc6ec9e64bb/Lib/bisect.py#L67
      len = length
      lo = 0
      hi = len

      while lo < hi
        mid = (lo + hi).div(2)

        if yield self[mid]
          hi = mid
        else
          lo = mid + 1
        end
      end

      lo == len ? nil : lo
    end
  end

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