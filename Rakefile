Dir.chdir File.dirname __FILE__

namespace :ruby do
  perf_dir = File.expand_path "perf/Ruby"

  desc "Run the mruby test suite"
  task :test do
    sh "rspec"
  end

  desc "Run the benchmark #{perf_dir}/benchmark_[name].rb"
  task :benchmark, [:name, :batch_size] do |t, args|
    file = "#{perf_dir}/benchmark_#{args.name}.rb"
    args.with_defaults name: "calls_awaiting"
    sh "ruby #{file} #{args.batch_size}"
  end

  desc "Create a code profile by running #{perf_dir}/profile_[name].rb"
  task :profile, [:name] do |t, args|
    file = "#{perf_dir}/profile_#{args.name}.rb"
    args.with_defaults name: "call"
    sh "ruby #{file}"
  end
end

namespace :mruby do
  mruby_builds = File.expand_path "mruby_build"
  perf_dir = File.expand_path "perf/mruby"

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

  prod_source = "#{mruby_builds}/prod"
  mruby = "#{prod_source}/bin/mruby"

  namespace :prod do
    file prod_source do
      sh "git clone --depth=1 git://github.com/mruby/mruby.git #{prod_source}"
    end

    file mruby => prod_source do
      sh "cd #{prod_source} && MRUBY_CONFIG=#{mruby_builds}/prod_build_config.rb rake"
    end

    desc "Build a production-grade mruby binary"
    task build: mruby

    desc "Clean the mruby production build"
    task clean: prod_source do
      sh "cd #{prod_source} && rake deep_clean"
    end

    desc "Update the source for the mruby production build"
    task pull: prod_source do
      sh "cd #{prod_source} && git pull"
    end
  end

  desc "Run the benchmark #{perf_dir}/benchmark_[name].rb"
  task :benchmark, [:file, :batch_size] => mruby do |t, args|
    file = "#{perf_dir}/benchmark_#{args.file}.rb"
    args.with_defaults file: "calls_awaiting"
    sh "#{mruby} #{file} #{args.batch_size}"
  end

  dev_source = "#{mruby_builds}/dev"
  mruby_dev = "#{dev_source}/bin/mruby"

  namespace :dev do
    file dev_source do
      sh "git clone --depth=1 git://github.com/mruby/mruby.git #{dev_source}"
    end

    file mruby_dev => dev_source do
      sh "cd #{dev_source} && MRUBY_CONFIG=#{mruby_builds}/dev_build_config.rb rake"
    end

    desc "Build an mruby binary for debugging (MRB_DEBUG, MRB_ENABLE_DEBUG_HOOK, mruby-profiler)"
    task build: mruby_dev

    desc "Clean the mruby debug build"
    task clean: dev_source do
      sh "cd #{dev_source} && rake deep_clean"
    end

    desc "Update the source for the mruby debug build"
    task pull: dev_source do
      sh "cd #{dev_source} && git pull"
    end
  end
end

desc "Run the Ruby and mruby test suites"
task test: %w(ruby:test mruby:test)

task default: :test