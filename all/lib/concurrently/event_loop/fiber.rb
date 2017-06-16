module Concurrently
  # @private
  class EventLoop::Fiber < ::Fiber
    def initialize(run_queue, io_selector, proc_fiber_pool)
      super() do
        begin
          while true
            if (waiting_time = run_queue.waiting_time) == 0
              # Check ready IOs although fibers are ready to run to not neglect
              # IO operations. Otherwise, IOs might become jammed since they
              # are constantly written to but not read from.
              # This behavior is not covered in the test suite. It becomes
              # apparent only in situations of heavy load where this event loop
              # has not much time to breathe.
              io_selector.process_ready_in waiting_time if io_selector.awaiting?

              run_queue.process_pending
            elsif io_selector.awaiting? or waiting_time
              io_selector.process_ready_in waiting_time
            else
              # Having no pending timeouts or IO events would make run this loop
              # forever. But, since we always start the loop from one of the
              # *await* methods, it is also always returning to them after waiting
              # is complete. Therefore, we never reach this part of the code unless
              # there is a bug or it is messed around with the internals of this gem.
              raise Error, "Infinitely running event loop detected: There " <<
                "are no concurrent procs or fibers scheduled and no IOs to await."
            end
          end
        rescue Exception => error
          Concurrently::EventLoop.current.reinitialize!
          raise Error, "Event loop teared down (#{error.class}: #{error.message})", error.backtrace
        end
      end
    end
  end
end