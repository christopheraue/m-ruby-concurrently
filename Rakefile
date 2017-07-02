Dir.chdir File.dirname __FILE__

namespace :ruby do
  perf_dir = File.expand_path "perf"

  task :test do
    sh "rspec"
  end

  task :benchmark, [:file, :batch_size] do |t, args|
    args.with_defaults file: "calls_awaiting"
    sh "ruby #{perf_dir}/benchmark_#{args.file}.rb #{args.batch_size}"
  end

  task :profile, [:file] do |t, args|
    args.with_defaults file: "call"
    sh "ruby #{perf_dir}/profile_#{args.file}.rb"
  end
end

namespace :mruby do
  mruby_env = File.expand_path "mruby_build"
  mruby_dir = "#{mruby_env}/mruby"
  
  file mruby_dir do
    sh "git clone --depth=1 git://github.com/mruby/mruby.git #{mruby_dir}"
  end

  task test: mruby_dir do
    sh "cd #{mruby_dir} && MRUBY_CONFIG=#{mruby_env}/build_config.rb rake test"
  end
  task build: :test

  task clean: mruby_dir do
    sh "cd #{mruby_dir} && rake deep_clean"
  end

  task pull: mruby_dir do
    sh "cd #{mruby_dir} && git pull"
  end
end

task test: %w(ruby:test mruby:test)

task default: :test