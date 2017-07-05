class Stage
  def profile(opts = {})
    gc_disabled do
      execute(opts){ yield }
    end
  end
end

