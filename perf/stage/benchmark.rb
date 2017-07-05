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

    def initialize(stage, name, opts = {})
      @stage = stage
      @name = name
      @opts = opts

      opts[:call] ||= :call_nonblock
      opts[:batch_size] ||= 1

      proc_lines = opts[:proc].chomp.split "\n"
      proc_lines[0] = "test_proc = #{proc_lines[0]}"

      args_lines = if opts[:batch_size] > 1
        if opts[:args]
          args_lines = opts[:args].chomp.split("\n").map!{ |line| line.prepend "  " }
          ["batch = Array.new(#{opts[:batch_size]}) do |idx|", *args_lines, "end"]
        else
          ["batch = Array.new(#{opts[:batch_size]})"]
        end
      elsif opts[:args]
        args_lines = opts[:args].chomp.split("\n")
        if args_lines.size > 1
          args_lines.map!{ |line| line.prepend "  " }
          ["args = begin", *args_lines, "end"]
        else
          args_lines
        end
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
        call_raw = "test_proc.#{@opts[:call]}" << (opts[:args] ? "(*args)" : "")

        if opts[:sync]
          case @opts[:call]
          when :call_nonblock, :call_detached
            ["evaluation = #{call_raw}", "evaluation.await_result"]
          when :call
            [call_raw, "# Concurrently::Proc#call already synchronizes the results of evaluations"]
          when :call_and_forget
            [call_raw, "wait 0"]
          end
        else
          [call_raw]
        end
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