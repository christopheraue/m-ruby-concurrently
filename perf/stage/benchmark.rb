class Stage
  class Benchmark
    SECONDS = 1
    SYNCHRONIZE = {
      call: "# #call already synchronizes the results of evaluations",
      call_nonblock: "results.each{ |eval| eval.await_result }",
      call_detached: "results.each{ |eval| eval.await_result }",
      call_and_forget: "wait 0" }
    RESULT_HEADER = "Results for #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}"
    RESULT_FORMAT = "  %-25s %7d executions in %2.4f seconds"

    def self.header
      <<DOC
Benchmark
=========
DOC
    end

    def self.result_header
      "#{RESULT_HEADER}\n#{'-'*RESULT_HEADER.length}"
    end

    def initialize(stage, name, opts = {})
      @stage = stage
      @name = name

      @batch = Array.new(opts[:batch_size] || 1)
      self.proc = opts[:proc]
      self.call = opts[:call] || :call_nonblock
      self.args = opts[:args]
      self.sync = opts[:sync]
    end

    def desc
      batch_args = @args_src ? <<ARGS.chomp! : nil
do |idx|
      #{@args_src}
    end
ARGS
      synchronize = @synchronize ? <<SYNCHRONIZE.chomp! : nil
.tap do |results|
        #{SYNCHRONIZE[@call]}
      end
SYNCHRONIZE

      <<DOC
  #{@name}:
    proc = #{@proc_src.gsub("\n", "\n    ")}
    batch = Array.new(#{@batch.size}) #{batch_args}

    while elapsed_seconds < #{SECONDS}
      batch.map{ |*args| proc.#{@call} *args }#{synchronize}
    end

DOC
    end

    def proc=(proc)
      @proc_src = proc
      @proc = eval proc
    end

    def call=(call)
      @call = call
      @tester = eval "proc{ |*args| @proc.#{call} *args }"
      @synchronize = eval <<-CODE
        proc do |results|
          #{SYNCHRONIZE[call]}
        end
      CODE
    end

    def args=(args)
      @args_src = args
      eval "@batch.fill{ #{args} }"
    end

    def sync=(sync)
      @synchronize = sync ? eval(<<-CODE) : nil
        proc do |results|
          #{SYNCHRONIZE[@call]}
        end
      CODE
    end

    def run
      result = @stage.gc_disabled do
        @stage.execute(seconds: SECONDS) do
          result = @batch.map(&@tester)
          @synchronize.call result if @synchronize
        end
      end
      puts sprintf(RESULT_FORMAT, "#{@name}:", @batch.size*result[:iterations], result[:time])
    end
  end
end