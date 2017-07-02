MRuby::Build.new do |conf|
  toolchain :gcc
  conf.enable_test
  conf.gem core: 'mruby-bin-mruby'
  conf.gem core: 'mruby-bin-mirb'
  conf.gem File.expand_path File.dirname File.dirname __FILE__
end