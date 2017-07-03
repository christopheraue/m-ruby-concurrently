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
  mruby_builds = File.expand_path "mruby_build"

  test_source = "#{mruby_builds}/test"
  mrbtest = "#{test_source}/bin/mrbtest"

  namespace :test do
    file test_source do
      sh "git clone --depth=1 git://github.com/mruby/mruby.git #{test_source}"
    end

    file mrbtest => test_source do
      sh "cd #{test_source} && MRUBY_CONFIG=#{mruby_builds}/test_build_config.rb rake"
    end

    task build: mrbtest

    task clean: test_source do
      sh "cd #{test_source} && rake deep_clean && rm #{mrbtest}"
    end

    task pull: test_source do
      sh "cd #{test_source} && git pull"
    end
  end

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

    task build: mruby
    
    task clean: prod_source do
      sh "cd #{prod_source} && rake deep_clean"
    end

    task pull: prod_source do
      sh "cd #{prod_source} && git pull"
    end
  end

  task :benchmark, [:file, :batch_size] => mruby do |t, args|
    perf_dir = File.expand_path "perf/mruby"
    args.with_defaults file: "calls_awaiting"
    sh "#{mruby} #{perf_dir}/benchmark_#{args.file}.rb #{args.batch_size}"
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

    task build: mruby_dev
    
    task clean: dev_source do
      sh "cd #{dev_source} && rake deep_clean"
    end

    task pull: dev_source do
      sh "cd #{dev_source} && git pull"
    end
  end
end

task test: %w(ruby:test mruby:test)

task default: :test