# Performance of Concurrently

The performance is measured by comparing all `#call` methods of a concurrent
proc and a regular proc in Ruby 2.4.1 on an Intel i7-5820K 3.3 GHz. Garbage
collection is disabled during the measurements.

## Calling a (Concurrent) Proc

    Benchmarked Code
    ----------------
      proc = proc{}
      conproc = concurrent_proc{}
      
      while elapsed_seconds < 1
        # CODE #
      end
    
    Results
    -------
      # CODE #
      proc.call:                5423106 executions in 1.0000 seconds
      conproc.call:              662314 executions in 1.0000 seconds
      conproc.call_nonblock:     769164 executions in 1.0000 seconds
      conproc.call_detached:     269385 executions in 1.0000 seconds
      conproc.call_and_forget:   306099 executions in 1.0000 seconds
      Fiber.new{}:               427472 executions in 1.0000 seconds

Explanation of the results:

* The difference between a regular and a concurrent proc is caused by
concurrent procs being evaluated in a fiber.
* Of the two methods evaluating the proc in the foreground `#call_nonblock`
is faster than `#call`, because the implementation of `#call` uses
`#call_nonblock` and does a little bit more on top.
* Of the two methods evaluating the proc in the background, `#call_and_forget`
is faster because `#call_detached` additionally creates an evaluation
object.
* Running concurrent procs in the background is slower by a good chunk because
in this setup `#call_detached` and `#call_and_forget` cannot reuse fibers.
Their evaluation is merely scheduled and not started and concluded. This would
happen during the next iteration of the event loop. But since the `while` loop
never waits for something [the loop is never entered]
[Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run].
All this leads to the creation of a new fiber for each evaluation. This is
responsible for the largest chunk of time take during the measurement. The
rest of the time is spent scheduling the concurrent procs.

You can run the benchmark yourself by running the script [perf/concurrent_proc_calls.rb][].

[perf/concurrent_proc_calls.rb]: https://github.com/christopheraue/m-ruby-concurrently/blob/master/perf/concurrent_proc_calls.rb
[Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Troubleshooting.md#A_concurrent_proc_is_scheduled_but_never_run