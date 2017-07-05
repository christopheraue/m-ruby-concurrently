Dir.chdir File.dirname __FILE__

perf_dir = File.expand_path "perf"

# Ruby
ruby = {
  test: "rspec" ,
  benchmark: "ruby -Iperf/Ruby -rstage",
  profile: "ruby -Iperf/Ruby -rstage" }

mruby_dir = File.expand_path "mruby_builds"
mruby = {
  src: "#{mruby_dir}/_source",
  cfg: "#{mruby_dir}/build_config.rb",
  test: "#{mruby_dir}/test/bin/mrbtest",
  benchmark: "#{mruby_dir}/benchmark/bin/mruby",
  profile: "#{mruby_dir}/profile/bin/mruby" }

namespace :test do
  desc "Run the Ruby test suite"
  task :ruby do
    sh ruby[:test]
  end

  desc "Run the mruby test suite"
  task :mruby, [:reference] => "mruby:build" do
    sh mruby[:test]
  end
end

desc "Run the Ruby and mruby test suites"
task test: %w(test:ruby test:mruby)

namespace :benchmark do
  desc "Run the benchmark #{perf_dir}/benchmark_[name].rb with Ruby"
  task :ruby, [:name, :batch_size] do |t, args|
    args.with_defaults name: "wait_methods", batch_size: 1
    file = "#{perf_dir}/benchmark_#{args.name}.rb"
    sh "#{ruby[:benchmark]} #{file} #{args.batch_size}"
  end

  desc "Run the benchmark #{perf_dir}/benchmark_[name].rb with mruby"
  task :mruby, [:name, :batch_size] => "mruby:build" do |t, args|
    args.with_defaults name: "wait_methods", batch_size: 1
    file = "#{perf_dir}/benchmark_#{args.name}.rb"
    sh "#{mruby[:benchmark]} #{file} #{args.batch_size}"
  end
end

desc "Run the benchmark #{perf_dir}/benchmark_[name].rb for Ruby and mruby"
task :benchmark, [:name, :batch_size] => "mruby:build" do |t, args|
  args.with_defaults name: "wait_methods", batch_size: 1
  file = "#{perf_dir}/benchmark_#{args.name}.rb"
  sh "#{ruby[:benchmark]} #{file} #{args.batch_size}", verbose: false
  sh "#{mruby[:benchmark]} #{file} #{args.batch_size} skip_header", verbose: false
end

namespace :profile do
  desc "Create a code profile by running #{perf_dir}/profile_[name].rb with Ruby"
  task :ruby, [:name] do |t, args|
    args.with_defaults name: "call"
    file = "#{perf_dir}/profile_#{args.name}.rb"
    sh "#{ruby[:profile]} #{file}"
  end

  desc "Create a code profile by running #{perf_dir}/profile_[name].rb with mruby"
  task :mruby, [:name] => "mruby:build" do |t, args|
    args.with_defaults name: "call"
    file = "#{perf_dir}/profile_#{args.name}.rb"
    sh "#{mruby[:profile]} #{file}"
  end
end

namespace :mruby do
  file mruby[:src] do
    sh "git clone --depth=1 git://github.com/mruby/mruby.git #{mruby[:src]}"
  end

  desc "Checkout a tag or commit of the mruby source. Executes: git checkout reference"
  task :checkout, [:reference] => mruby[:src] do |t, args|
    args.with_defaults reference: 'master'
    `cd #{mruby[:src]} && git fetch --tags`
    current_ref = `cd #{mruby[:src]} && git rev-parse HEAD`
    checkout_ref = `cd #{mruby[:src]} && git rev-parse #{args.reference}`
    if checkout_ref != current_ref
      Rake::Task['mruby:clean'].invoke
      sh "cd #{mruby[:src]} && git checkout #{args.reference}"
    end
  end

  desc "Build mruby"
  task :build, [:reference] => :checkout do
    sh "cd #{mruby[:src]} && MRUBY_CONFIG=#{mruby[:cfg]} rake"
  end

  desc "Clean the mruby build"
  task clean: mruby[:src] do
    sh "cd #{mruby[:src]} && MRUBY_CONFIG=#{mruby[:cfg]} rake deep_clean"
  end

  desc "Update the source of mruby"
  task pull: mruby[:src] do
    sh "cd #{mruby[:src]} && git pull"
  end

  desc "Delete the mruby source"
  task delete: mruby[:src] do
    sh "rm -rf #{mruby[:src]}"
  end
end

task default: :test