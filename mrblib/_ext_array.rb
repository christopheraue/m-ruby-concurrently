# @private
class Array
  unless method_defined? :bsearch_index
    # Implements Array#bsearch_index for mruby and Ruby < 2.3.
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
end