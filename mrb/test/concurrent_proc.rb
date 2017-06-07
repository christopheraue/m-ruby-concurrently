conproc = concurrent_proc do |result|
  result
end

assert "concurrent_proc#call" do
  assert_equal conproc.call(:result), :result

  assert_raise RuntimeError, "error" do
    concurrent_proc{ raise "error" }.call
  end
end

assert "concurrent_proc#call_nonblock" do
  assert_equal conproc.call_nonblock(:result), :result
end

assert "concurrent_proc#call_detached" do
  assert_kind_of Concurrently::Proc::Evaluation, conproc.call_detached(:result)
end

assert "concurrent_proc#call_and_forget" do
  assert_equal conproc.call_and_forget(:result), nil
end