class Stage
  class Benchmark
    class CodeGen
      class Batch < CodeGen
        def initialize(*args, batch_size)
          super *args
          @batch_size = batch_size
        end

        def args_lines
          case (lines = super).size
          when 0
            ["batch = Array.new(#{@batch_size})"]
          else
            lines.each{ |l| l.insert 0, "  " }
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
          lines[1..-2].each{ |l| l.insert 0, "  " }
          lines
        end
      end
    end
  end
end