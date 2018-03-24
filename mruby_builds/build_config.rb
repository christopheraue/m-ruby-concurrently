MRuby::Build.new do
  if ENV['VisualStudioVersion'] || ENV['VSINSTALLDIR']
    toolchain :visualcpp
  else
    toolchain :gcc
  end

  enable_debug
end

MRuby::Build.new 'test', File.dirname(__FILE__) do
  self.gem_clone_dir = "#{MRUBY_ROOT}/build/mrbgems"

  if ENV['VisualStudioVersion'] || ENV['VSINSTALLDIR']
    toolchain :visualcpp
  else
    toolchain :gcc
  end

  enable_test
  gem File.expand_path File.dirname File.dirname __FILE__
end

MRuby::Build.new 'benchmark', File.dirname(__FILE__) do
  self.gem_clone_dir = "#{MRUBY_ROOT}/build/mrbgems"

  if ENV['VisualStudioVersion'] || ENV['VSINSTALLDIR']
    toolchain :visualcpp
  else
    toolchain :gcc
    cc.flags << '-O3'
  end

  gem core: 'mruby-bin-mruby'
  gem core: 'mruby-bin-mirb'
  gem core: 'mruby-proc-ext'
  gem core: 'mruby-sprintf'
  gem core: 'mruby-eval'

  gem_dir = File.expand_path File.dirname File.dirname __FILE__
  gem gem_dir do |gem|
    gem.rbfiles += Dir["#{gem_dir}/perf/{stage.rb,stage/**/*.rb}"]
  end
end

MRuby::Build.new 'profile', File.dirname(__FILE__) do
  self.gem_clone_dir = "#{MRUBY_ROOT}/build/mrbgems"

  if ENV['VisualStudioVersion'] || ENV['VSINSTALLDIR']
    toolchain :visualcpp
  else
    toolchain :gcc
  end

  enable_debug
  cc.defines = %w(MRB_ENABLE_DEBUG_HOOK)

  # Use own, fixed version of mruby-profiler until the fix is merged upstream
  # gem github: 'miura1729/mruby-profiler'
  gem github: 'christopheraue/mruby-profiler', :branch => 'mrb_method_t_fix'

  gem core: 'mruby-bin-mruby'
  gem core: 'mruby-proc-ext'
  gem core: 'mruby-sprintf'

  gem_dir = File.expand_path File.dirname File.dirname __FILE__
  gem gem_dir do |gem|
    gem.rbfiles << "#{gem_dir}/perf/stage.rb" << "#{gem_dir}/perf/mruby/stage.rb"
  end
end