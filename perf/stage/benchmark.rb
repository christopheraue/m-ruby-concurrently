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
Benchmarks
----------
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

      batch_size = opts[:batch_size] || 1

      if batch_size > 1
        @code = proc do
          results = @batch.map(&@tester)
          @synchronize.call results if @synchronize
        end
      else
        @code = eval <<-CODE
          proc do
            result = @proc.#{@call} @batch[0]
            @synchronize.call [result] if @synchronize
          end
        CODE
      end
    end

    def desc_batch_args
      @args_src ? <<ARGS.chomp! : nil
do |idx|
      #{@args_src}
    end
ARGS
    end

    def desc_code
        if @args_src
          <<ARGS.chomp!
args = begin
      #{@args_src}
    end
    proc.#{@call} *args
ARGS
        else
          "proc.#{@call}"
        end
    end

    def desc_batch_test
      synchronize = @synchronize ? <<SYNCHRONIZE.chomp! : nil
.tap do |results|
        #{SYNCHRONIZE[@call]}
      end
SYNCHRONIZE

      <<DESC.chomp!
batch = Array.new(#{@batch.size}) #{desc_batch_args}

    while elapsed_seconds < #{SECONDS}
      batch.map{ |*args| proc.#{@call} *args }#{synchronize}
    end
DESC
    end

    def desc_single_test
      if @synchronize
        <<DESC.chomp!
while elapsed_seconds < #{SECONDS}
      #{desc_code}
    end
DESC
      else
        <<DESC.chomp!
while elapsed_seconds < #{SECONDS}
      #{desc_code}
    end
DESC
      end
    end

    def desc_test
      if @batch.size > 1
        desc_batch_test
      else
        desc_single_test
      end
    end

    def desc
      <<DOC
  #{@name}:
    proc = #{@proc_src.gsub("\n", "\n    ")}
    #{desc_test}

DOC
    end

    def proc=(proc)
      @proc_src = proc
      @proc = eval proc
    end

    def call=(call)
      @call = call
      @tester = eval "proc{ |*args| @proc.#{call} *args }"
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
        @stage.execute(seconds: SECONDS, &@code)
      end
      puts sprintf(RESULT_FORMAT, "#{@name}:", @batch.size*result[:iterations], result[:time])
    end
  end
end