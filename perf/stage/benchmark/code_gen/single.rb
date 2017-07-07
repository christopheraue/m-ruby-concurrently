class Stage
  class Benchmark
    class CodeGen
      class Single < CodeGen
        def args_lines
          case (lines = super).size
          when 0
            lines
          when 1
            lines[0] = "args = #{lines[0]}"
          else
            lines.each{ |l| l.replace "  #{l}" }
            lines.unshift "args = begin"
            lines.push "end"
          end
        end

        def call_lines
          lines = super
          if @sync
            @sync = @call if @sync == true
            case @sync
            when :call_nonblock, :call_detached, :await_result
              lines[1] = "evaluation = #{lines[1]}"
              lines.insert 2, "evaluation.await_result"
            when :call
              lines.insert 2, "# Concurrently::Proc#call already synchronizes the results of evaluations"
            when :call_and_forget, :wait
              lines.insert 2, "wait 0"
            end
          end
          lines[1..-2].each{ |l| l.replace "  #{l}" }
          lines
        end
      end
    end
  end
end