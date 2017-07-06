class Stage
  class Benchmark
    class CodeGen
      def initialize(opts)
        opts.each do |key, value|
          instance_variable_set "@#{key}", value
        end
      end

      def proc_lines
        @proc.chomp.split("\n").tap do |lines|
          lines[0] = "test_proc = #{lines[0]}"
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
  end
end