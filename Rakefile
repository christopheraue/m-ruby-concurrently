Dir.chdir File.dirname __FILE__

namespace :ruby do
  perf_dir = File.expand_path "perf/Ruby"

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
  mruby_build = File.expand_path "mruby_build"

  namespace :test do
    test_mruby = "#{mruby_build}/test"

    file test_mruby do
      sh "git clone --depth=1 git://github.com/mruby/mruby.git #{test_mruby}"
    end

    task run: test_mruby do
      sh "cd #{test_mruby} && MRUBY_CONFIG=#{mruby_build}/test_build_config.rb rake test"
    end

    task clean: test_mruby do
      sh "cd #{test_mruby} && rake deep_clean"
    end

    task pull: test_mruby do
      sh "cd #{test_mruby} && git pull"
    end
  end

  task test: 'test:run'

  perf_mruby = "#{mruby_build}/perf"

  file perf_mruby do
    sh "git clone --depth=1 git://github.com/mruby/mruby.git #{perf_mruby}"
  end

  namespace :benchmark do
    task clean: perf_mruby do
      sh "cd #{perf_mruby} && rake deep_clean"
    end

    task pull: perf_mruby do
      sh "cd #{perf_mruby} && git pull"
    end
  end

  task :benchmark, [:file, :batch_size] => perf_mruby do |t, args|
    perf_dir = File.expand_path "perf/mruby"
    args.with_defaults file: "calls_awaiting"
    sh "cd #{perf_mruby} && MRUBY_CONFIG=#{mruby_build}/perf_build_config.rb rake && bin/mruby #{perf_dir}/benchmark_#{args.file}.rb #{args.batch_size}"
  end

  debug_mruby = "#{mruby_build}/debug"

  file debug_mruby do
    sh "git clone --depth=1 git://github.com/mruby/mruby.git #{debug_mruby}"
  end

  namespace :debug do
    task clean: debug_mruby do
      sh "cd #{debug_mruby} && rake deep_clean"
    end

    task pull: debug_mruby do
      sh "cd #{debug_mruby} && git pull"
    end

    task build: debug_mruby do |t, args|
      sh "cd #{debug_mruby} && MRUBY_CONFIG=#{mruby_build}/perf_build_config.rb rake"
    end
  end
end

task test: %w(ruby:test mruby:test)

task default: :test