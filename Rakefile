Dir.chdir File.dirname __FILE__

perf_dir = File.expand_path "perf"

# Ruby
ruby = {
  test: { exe: "rspec" },
  benchmark: { exe: "ruby -Iperf/Ruby -rstage" },
  profile: { exe: "ruby -Iperf/Ruby -rstage" } }

mruby_dir = File.expand_path "mruby_builds"
mruby = {
  test: {
    dir: "#{mruby_dir}/test",
    cfg: "#{mruby_dir}/test_build_config.rb",
    exe: "#{mruby_dir}/test/bin/mrbtest" },
  benchmark: {
    dir: "#{mruby_dir}/benchmark",
    cfg: "#{mruby_dir}/benchmark_build_config.rb",
    exe: "#{mruby_dir}/benchmark/bin/mruby" },
  profile: {
    dir: "#{mruby_dir}/profile",
    cfg: "#{mruby_dir}/profile_build_config.rb",
    exe: "#{mruby_dir}/profile/bin/mruby" } }

namespace :test do
  desc "Run the Ruby test suite"
  task :ruby do
    sh ruby[:test][:exe]
  end

  desc "Run the mruby test suite"
  task :mruby do
    Rake::Task["mruby:build"].invoke :test
    sh mruby[:test][:exe]
  end
end

desc "Run the Ruby and mruby test suites"
task test: %w(test:ruby test:mruby)

namespace :benchmark do
  desc "Run the benchmark #{perf_dir}/benchmark_[name].rb with Ruby"
  task :ruby, [:name, :batch_size] do |t, args|
    args.with_defaults name: "calls_awaiting", batch_size: 1
    file = "#{perf_dir}/benchmark_#{args.name}.rb"
    sh "#{ruby[:benchmark][:exe]} #{file} #{args.batch_size}"
  end

  desc "Run the benchmark #{perf_dir}/benchmark_[name].rb with mruby"
  task :mruby, [:name, :batch_size] do |t, args|
    Rake::Task["mruby:build"].invoke :benchmark
    args.with_defaults name: "calls_awaiting", batch_size: 1
    file = "#{perf_dir}/benchmark_#{args.name}.rb"
    sh "#{mruby[:benchmark][:exe]} #{file} #{args.batch_size}"
  end
end

desc "Run the benchmark #{perf_dir}/benchmark_[name].rb for Ruby and mruby"
task :benchmark, [:name, :batch_size] do |t, args|
  Rake::Task["mruby:build"].invoke :benchmark
  args.with_defaults name: "calls_awaiting", batch_size: 1
  file = "#{perf_dir}/benchmark_#{args.name}.rb"
  sh "#{ruby[:benchmark][:exe]} #{file} #{args.batch_size}", verbose: false
  sh "#{mruby[:benchmark][:exe]} #{file} #{args.batch_size} skip_header", verbose: false
end

namespace :profile do
  desc "Create a code profile by running #{perf_dir}/profile_[name].rb with Ruby"
  task :ruby, [:name] do |t, args|
    args.with_defaults name: "call"
    file = "#{perf_dir}/profile_#{args.name}.rb"
    sh "#{ruby[:profile][:exe]} #{file}"
  end

  desc "Create a code profile by running #{perf_dir}/profile_[name].rb with mruby"
  task :mruby, [:name] do |t, args|
    Rake::Task["mruby:build"].invoke :profile
    args.with_defaults name: "call"
    file = "#{perf_dir}/profile_#{args.name}.rb"
    sh "#{mruby[:profile][:exe]} #{file}"
  end
end

namespace :mruby do
  mruby.each_value do |config|
    file config[:dir] do
      sh "git clone --depth=1 git://github.com/mruby/mruby.git #{config[:dir]}"
    end
  end

  task :build, [:env] do |t, args|
    env = args.env.to_sym
    Rake::Task[mruby[env][:dir]].invoke
    sh "cd #{mruby[env][:dir]} && MRUBY_CONFIG=#{mruby[env][:cfg]} rake"
  end

  desc "Clean the mruby [#{mruby.keys.join(',')}] build"
  task :clean, [:env] do |t, args|
    env = args.env.to_sym
    sh "cd #{mruby[env][:dir]} && rake deep_clean && rm -f #{mruby[:profile][:exe]}"
  end

  desc "Update the source for the mruby [#{mruby.keys.join(',')}] build"
  task :pull, [:env] do |t, args|
    env = args.env.to_sym
    sh "cd #{mruby[env][:dir]} && git pull"
  end

  desc "Delete the mruby [#{mruby.keys.join(',')}] build"
  task :delete, [:env] do |t, args|
    env = args.env.to_sym
    sh "rm -rf #{mruby[env][:dir]}"
  end
end

task default: :test