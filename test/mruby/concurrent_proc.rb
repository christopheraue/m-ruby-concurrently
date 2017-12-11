conproc = concurrent_proc do |result|
  result
end

assert "concurrent_proc#call" do
  assert_equal conproc.call(:result), :result

  Concurrently::Proc.error_log_output = nil
  assert_raise RuntimeError, "error" do
    concurrent_proc{ raise "error" }.call
  end
  Concurrently::Proc.error_log_output = STDERR
end

assert "concurrent_proc#call_nonblock" do
  assert_equal conproc.call_nonblock(:result), :result
end

assert "concurrent_proc#call_detached" do
  assert_true conproc.call_detached(:result).kind_of? Concurrently::Proc::Evaluation
end

assert "concurrent_proc#call_and_forget" do
  assert_equal conproc.call_and_forget(:result), nil
end