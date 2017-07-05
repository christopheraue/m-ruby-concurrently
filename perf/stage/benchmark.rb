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

    class CodeGen
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
        if @args
          @args.chomp.split("\n")
        else
          []
        end
      end

      def call_lines
        ["proc do", "test_proc.#{@call}#{(@args ? "(*args)" : "")}", "end"]
      end
    end

    class SingleCodeGen < CodeGen
      def args_lines
        case (lines = super).size
        when 0
          lines
        when 1
          lines[0].prepend "args = "
        else
          lines.map!{ |l| l.prepend "  " }
          lines.unshift "args = begin"
          lines.push "end"
        end
      end

      def call_lines
        lines = super
        if @sync
          case @call
          when :call_nonblock, :call_detached
            lines[1].prepend "evaluation = "
            lines.insert 2, "evaluation.await_result"
          when :call
            lines.insert 2, "# Concurrently::Proc#call already synchronizes the results of evaluations"
          when :call_and_forget
            lines.insert 2, "wait 0"
          end
        end
        lines[1..-2].each{ |l| l.prepend '  ' }
        lines
      end
    end

    class BatchCodeGen < CodeGen
      def initialize(*args, batch_size)
        super *args
        @batch_size = batch_size
      end

      def args_lines
        case (lines = super).size
        when 0
          ["batch = Array.new(#{@batch_size})"]
        else
          lines.map!{ |l| l.prepend "  " }
          lines.unshift "batch = Array.new(#{@batch_size}) do |idx|"
          lines.push "end"
        end
      end

      def call_lines
        lines = super
        blk = "{#{@args ? " |*args|" : nil} #{lines[1]} }"
        if @sync
          case @call
          when :call_nonblock, :call_detached
            lines[1] = "evaluations = batch.map#{blk}"
            lines.insert 2, "evaluations.each{ |evaluation| evaluation.await_result }"
          when :call
            lines[1] = "batch.each#{blk}"
            lines.insert 2, "# Concurrently::Proc#call already synchronizes the results of evaluations"
          when :call_and_forget
            lines[1] = "batch.each#{blk}"
            lines.insert 2, "wait 0"
          end
        else
          lines[1] = "batch.each#{blk}"
        end
        lines[1..-2].each{ |l| l.prepend '  ' }
        lines
      end
    end

    def initialize(stage, name, opts = {})
      @stage = stage
      @name = name
      @opts = opts

      proc = opts[:proc]
      call = opts[:call] || :call_nonblock
      args = opts[:args]
      sync = opts[:sync]
      batch_size = opts[:batch_size] || 1

      code_gen = if batch_size > 1
        BatchCodeGen.new(proc, call, args, sync, batch_size)
      else
        SingleCodeGen.new(proc, call, args, sync)
      end

      proc_lines = code_gen.proc_lines
      args_lines = code_gen.args_lines
      call_lines = code_gen.call_lines
      @code = eval [*proc_lines, *args_lines, "", *call_lines].join "\n"

      call_lines[0] = "while elapsed_seconds < #{SECONDS}"
      @desc = ["  #{@name}:", *proc_lines, *args_lines, "", *call_lines, ""].join "\n    "
    end

    attr_reader :desc

    def run
      result = @stage.gc_disabled do
        @stage.execute(seconds: SECONDS, &@code)
      end
      puts sprintf(RESULT_FORMAT, "#{@name}:", @opts[:batch_size]*result[:iterations], result[:time])
    end
  end
end