class IO
  include(Kernel.dup.class_eval do
    (instance_methods - %i(hash)).each{ |m| remove_method m }
    self
  end)
end