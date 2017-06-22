# Performance of Concurrently

Overall, Concurrently is able to schedule around 100k to 200k concurrent
evaluations per second. What to expect exactly is narrowed down in the
following benchmarks.

The measurements are executed with Ruby 2.4.1 on an Intel i7-5820K 3.3 GHz
running Linux 4.10. Garbage collection is disabled.


## Calling a (Concurrent) Proc

This benchmark compares all `#call` methods of a concurrent proc and a regular
proc. The mere invocation of the method is measured. The proc itself does
nothing.

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

Explanation of the results:

* The difference between a regular and a concurrent proc is caused by
  concurrent procs being evaluated in a fiber and doing some bookkeeping.
* Of the two methods evaluating the proc in the foreground `#call_nonblock`
  is faster than `#call`, because the implementation of `#call` uses
  `#call_nonblock` and does a little bit more on top.
* Of the two methods evaluating the proc in the background, `#call_and_forget`
  is faster because `#call_detached` additionally creates an evaluation
  object.
* Running concurrent procs in the background is considerably slower because
  in this setup `#call_detached` and `#call_and_forget` cannot reuse fibers.
  Their evaluation is merely scheduled and not started and concluded. This
  would happen during the next iteration of the event loop. But since the
  `while` loop never waits for something [the loop is never entered]
  [Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run].
  All this leads to the creation of a new fiber for each evaluation. This is
  responsible for the largest chunk of time needed during the measurement.

You can run the benchmark yourself by running the [script][perf/concurrent_proc_calls.rb]:

    $ perf/concurrent_proc_calls.rb


## Scheduling (Concurrent) Procs

This benchmark is closer to the real usage of Concurrently. It includes waiting
inside a concurrent proc.

    Benchmarked Code
    ----------------
      conproc = concurrent_proc{ wait 0 }
      
      while elapsed_seconds < 1
        1.times{ # CODE # }
        wait 0 # to enter the event loop
      end
    
    Results
    -------
      # CODE #
      conproc.call:               72444 executions in 1.0000 seconds
      conproc.call_nonblock:     103468 executions in 1.0000 seconds
      conproc.call_detached:     114882 executions in 1.0000 seconds
      conproc.call_and_forget:   117425 executions in 1.0000 seconds

Explanation of the results:

* Because scheduling is now the dominant factor, there is a large drop in the
  number of executions compared to just calling the procs. This makes the
  number of executions when calling the proc in a non-blocking way comparable.
* Calling the proc in a blocking manner with `#call` is costly. A lot of time
  is spend waiting for the result.

You can run the benchmark yourself by running the [script][perf/concurrent_proc_calls_awaiting.rb]:

    $ perf/concurrent_proc_calls_awaiting.rb


[perf/concurrent_proc_calls.rb]: https://github.com/christopheraue/m-ruby-concurrently/blob/master/perf/concurrent_proc_calls.rb
[perf/concurrent_proc_calls_awaiting.rb]: https://github.com/christopheraue/m-ruby-concurrently/blob/master/perf/concurrent_proc_calls_awaiting.rb
[Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Troubleshooting.md#A_concurrent_proc_is_scheduled_but_never_run