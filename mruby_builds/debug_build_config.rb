MRuby::Build.new do |conf|
  toolchain :gcc

  enable_debug
  conf.cc.defines = %w(MRB_ENABLE_DEBUG_HOOK)

  conf.gem github: 'miura1729/mruby-profiler'
  conf.gem core: 'mruby-bin-mruby'
  conf.gem core: 'mruby-bin-mirb'
  conf.gem core: 'mruby-proc-ext'
  conf.gem core: 'mruby-sprintf'

  gem_dir = File.expand_path File.dirname File.dirname __FILE__
  conf.gem gem_dir do |gem|
    gem.rbfiles << "#{gem_dir}/perf/stage.rb"
  end
end