class Stage
  class Benchmark
    class CodeGen
      class Batch < CodeGen
        def args_lines
          case (lines = super).size
          when 0
            ["batch = Array.new(#{@batch_size})"]
          else
            lines.each{ |l| l.replace "  #{l}" }
            lines.unshift "batch = Array.new(#{@batch_size}) do |idx|"
            lines.push "end"
          end
        end

        def call_lines
          lines = super
          blk = "{#{@args ? " |*args|" : nil} #{lines[1]} }"
          if @sync
            @sync = @call if @sync == true
            case @sync
            when :call_nonblock, :call_detached, :await_result
              lines[1] = "evaluations = batch.map#{blk}"
              lines.insert 2, "evaluations.each{ |evaluation| evaluation.await_result }"
            when :call
              lines[1] = "batch.each#{blk}"
              lines.insert 2, "# Concurrently::Proc#call already synchronizes the results of evaluations"
            when :call_and_forget, :wait
              lines[1] = "batch.each#{blk}"
              lines.insert 2, "wait 0"
            end
          else
            lines[1] = "batch.each#{blk}"
          end
          lines[1..-2].each{ |l| l.replace "  #{l}" }
          lines
        end
      end
    end
  end
end