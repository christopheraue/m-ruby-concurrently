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

    class BatchCodeGen
      def initialize(proc, call, args, sync, batch_size)
        @proc = proc
        @call = call
        @args = args
        @sync = sync
        @batch_size = batch_size
      end

      def proc_lines
        @proc.chomp.split("\n").tap do |lines|
          lines[0].prepend "test_proc = "
        end
      end

      def args_lines
        if @args
          @args.chomp.split("\n").tap do |lines|
            lines.map!{ |l| l.prepend "  " }
            lines.unshift "batch = Array.new(#{@batch_size}) do |idx|"
            lines.push "end"
          end
        else
          ["batch = Array.new(#{@batch_size})"]
        end
      end

      def call_lines
        blk_args  = @args ? " |*args|" : nil
        call_args = @args ? "(*args)" : nil

        ["{#{blk_args} test_proc.#{@call}#{call_args} }"].tap do |lines|
          if @sync
            case @call
            when :call_nonblock, :call_detached
              lines[0].prepend "evaluations = batch.map"
              lines.push "evaluations.each{ |evaluation| evaluation.await_result }"
            when :call
              lines[0].prepend "batch.each"
              lines.push "# Concurrently::Proc#call already synchronizes the results of evaluations"
            when :call_and_forget
              lines[0].prepend "batch.each"
              lines.push "wait 0"
            end
          else
            lines[0].prepend "batch.each"
          end
        end
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