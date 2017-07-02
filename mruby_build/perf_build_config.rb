MRuby::Build.new do |conf|
  toolchain :gcc
  conf.gem core: 'mruby-bin-mruby'
  conf.gem core: 'mruby-bin-mirb'
  conf.gem core: 'mruby-proc-ext'
  conf.gem core: 'mruby-sprintf'
  conf.gem File.expand_path File.dirname File.dirname __FILE__
end