class Stage
  class Benchmark
    SECONDS = 1
    RESULT_HEADER = "Results for #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}"
    RESULT_FORMAT = "  %-25s %8d executions in %2.4f seconds"

    def self.header
      <<DOC
Benchmarks
----------
DOC
    end

    def self.result_header
      "#{RESULT_HEADER}\n#{'-'*RESULT_HEADER.length}"
    end

    class SingleCodeGen
      def initialize(proc, call, args, sync)
        @proc = proc
        @call = call
        @args = args
        @sync = sync
      end

      def proc_lines
        @proc.chomp.split("\n").tap do |lines|
          lines[0].prepend "test_proc = "
        end
      end

      def args_lines
        return unless @args
        @args.chomp.split("\n").tap do |lines|
          next if lines.size == 1
          lines.map!{ |l| l.prepend "  " }
          lines.unshift "args = begin"
          lines.push "end"
        end
      end

      def call_lines
        call_args = (@args ? "(*args)" : "")
        ["test_proc.#{@call}#{call_args}"].tap do |lines|
          next unless @sync
          case @call
          when :call_nonblock, :call_detached
            lines[0].prepend "evaluation = "
            lines.push "evaluation.await_result"
          when :call
            lines.push "# Concurrently::Proc#call already synchronizes the results of evaluations"
          when :call_and_forget
            lines.push "wait 0"
          end
        end
      end
    end

    def initialize(stage, name, opts = {})
      @stage = stage
      @name = name
      @opts = opts

      opts[:call] ||= :call_nonblock
      opts[:batch_size] ||= 1

      single_code_gen = SingleCodeGen.new(opts[:proc], opts[:call], opts[:args], opts[:sync])

      proc_lines = single_code_gen.proc_lines

      args_lines = if opts[:batch_size] > 1
        if opts[:args]
          args_lines = opts[:args].chomp.split("\n").map!{ |line| line.prepend "  " }
          ["batch = Array.new(#{opts[:batch_size]}) do |idx|", *args_lines, "end"]
        else
          ["batch = Array.new(#{opts[:batch_size]})"]
        end
      else
        single_code_gen.args_lines
      end

      call_lines = if opts[:batch_size] > 1
        call_raw = if opts[:args]
          "batch.map{ |*args| test_proc.#{@opts[:call]}(*args) }"
        else
          "batch.map{ test_proc.#{@opts[:call]} }"
        end

        if opts[:sync]
          case @opts[:call]
          when :call_nonblock, :call_detached
            ["evaluations = #{call_raw}", "evaluations.each{ |evaluation| evaluation.await_result }"]
          when :call
            [call_raw, "# Concurrently::Proc#call already synchronizes the results of evaluations"]
          when :call_and_forget
            [call_raw, "wait 0"]
          end
        else
          [call_raw]
        end
      else
        single_code_gen.call_lines
      end

      call_lines.map!{ |l| l.prepend '  '} if call_lines
      @src_lines = [*proc_lines, *args_lines, "", "proc do", *call_lines, "end"]
      @code = eval @src_lines.join "\n"
    end

    def desc
      ["  #{@name}:", *@src_lines, ""].join "\n    "
    end

    def run
      result = @stage.gc_disabled do
        @stage.execute(seconds: SECONDS, &@code)
      end
      puts sprintf(RESULT_FORMAT, "#{@name}:", @opts[:batch_size]*result[:iterations], result[:time])
    end
  end
end