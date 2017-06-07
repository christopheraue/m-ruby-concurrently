assert "Kernel#wait" do
  assert_equal wait(0), true
end

assert "Kernel#concurrently" do
  ran = false
  concurrently{ ran = true }
  wait 0
  assert_true ran
end

assert "Kernel#concurrent_proc" do
  ran = false
  concurrent_proc{ ran = true }.call
  assert_true ran
end