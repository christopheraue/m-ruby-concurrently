Dir.chdir File.dirname __FILE__

namespace :ruby do

  desc "Run the mruby test suite"
  task :test do
    sh "rspec"
  end

  perf_dir = File.expand_path "perf"
  desc "Run the benchmark #{perf_dir}/benchmark_[name].rb"
  task :benchmark, [:name, :batch_size] do |t, args|
    args.with_defaults name: "calls_awaiting"
    file = "#{perf_dir}/benchmark_#{args.name}.rb"
    sh "ruby -Iperf/Ruby -rstage #{file} #{args.batch_size}"
  end

  desc "Create a code profile by running #{perf_dir}/profile_[name].rb"
  task :profile, [:name] do |t, args|
    args.with_defaults name: "call"
    file = "#{perf_dir}/profile_#{args.name}.rb"
    sh "ruby -Iperf/Ruby -rstage #{file}"
  end
end

namespace :mruby do
  mruby_builds = File.expand_path "mruby_builds"
  perf_dir = File.expand_path "perf"

  test_source = "#{mruby_builds}/test"
  mrbtest = "#{test_source}/bin/mrbtest"

  namespace :test do
    file test_source do
      sh "git clone --depth=1 git://github.com/mruby/mruby.git #{test_source}"
    end

    file mrbtest => test_source do
      sh "cd #{test_source} && MRUBY_CONFIG=#{mruby_builds}/test_build_config.rb rake"
    end

    desc "Build the mruby test runner (mrbtest)"
    task build: mrbtest

    desc "Clean the mruby test build"
    task clean: test_source do
      sh "cd #{test_source} && rake deep_clean && rm #{mrbtest}"
    end

    desc "Update the source for the mruby test build"
    task pull: test_source do
      sh "cd #{test_source} && git pull"
    end
  end

  desc "Run the Ruby test suite"
  task test: mrbtest do
    sh mrbtest
  end

  benchmark_source = "#{mruby_builds}/benchmark"
  mruby = "#{benchmark_source}/bin/mruby"

  namespace :benchmark do
    file benchmark_source do
      sh "git clone --depth=1 git://github.com/mruby/mruby.git #{benchmark_source}"
    end

    file mruby => benchmark_source do
      sh "cd #{benchmark_source} && MRUBY_CONFIG=#{mruby_builds}/benchmark_build_config.rb rake"
    end

    desc "Build a mruby binary for benchmarks"
    task build: mruby

    desc "Clean the mruby benchmark build"
    task clean: benchmark_source do
      sh "cd #{benchmark_source} && rake deep_clean"
    end

    desc "Update the source for the mruby benchmark build"
    task pull: benchmark_source do
      sh "cd #{benchmark_source} && git pull"
    end
  end

  desc "Run the benchmark #{perf_dir}/benchmark_[name].rb"
  task :benchmark, [:file, :batch_size] => mruby do |t, args|
    args.with_defaults file: "calls_awaiting"
    file = "#{perf_dir}/benchmark_#{args.file}.rb"
    sh "#{mruby} #{file} #{args.batch_size}"
  end

  debug_source = "#{mruby_builds}/debug"
  mruby_debug = "#{debug_source}/bin/mruby"

  namespace :debug do
    file debug_source do
      sh "git clone --depth=1 git://github.com/mruby/mruby.git #{debug_source}"
    end

    file mruby_debug => debug_source do
      sh "cd #{debug_source} && MRUBY_CONFIG=#{mruby_builds}/debug_build_config.rb rake"
    end

    desc "Build an mruby binary for debugging (MRB_DEBUG, MRB_ENABLE_DEBUG_HOOK, mruby-profiler)"
    task build: mruby_debug

    desc "Clean the mruby debug build"
    task clean: debug_source do
      sh "cd #{debug_source} && rake deep_clean"
    end

    desc "Update the source for the mruby debug build"
    task pull: debug_source do
      sh "cd #{debug_source} && git pull"
    end
  end
end

desc "Run the Ruby and mruby test suites"
task test: %w(ruby:test mruby:test)

task default: :test