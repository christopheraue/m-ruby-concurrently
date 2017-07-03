assert "Array#pop(n)" do
  array = [1,2,3,4,5]
  assert_equal array.pop(3), [3,4,5]
end