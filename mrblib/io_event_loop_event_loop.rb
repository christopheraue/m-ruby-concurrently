class IOEventLoop
  class EventLoop < Fiber
    def initialize(run_queue, io_watcher)
      super() do
        while true
          waiting_time = run_queue.waiting_time

          if waiting_time == 0
            run_queue.process_pending
          elsif io_watcher.awaiting? or waiting_time
            io_watcher.process_ready_in waiting_time
          else
            # Having no pending timeouts or IO events would make run this loop
            # forever. But, since we always start the loop from one of the
            # *await* methods, it is also always returning to them after waiting
            # is complete. Therefore, we never reach this part of the code unless
            # there is a bug or it is messed around with the internals of this gem.
            raise Error, "Infinitely running event loop detected. There either "\
            "is a bug in the io_event_loop gem or you messed around with the "\
            "internals of said gem."
          end
        end
      end
    end
  end
end