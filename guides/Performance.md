# Performance of Concurrently

Overall, Concurrently is able to execute around 100k moderately costly
concurrent evaluations per second. The upper bound for this value is narrowed
down in the following benchmarks.

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
  responsible for the largest chunk of time take during the measurement. The
  rest of the time is spent scheduling the concurrent procs.

You can run the benchmark yourself by running the script [perf/concurrent_proc_calls.rb][].

## Scheduling

This is a benchmark being closer to the real usage of Concurrently. It
includes scheduling an evaluation once per iteration of the event loop.

Each iteration of the `while` loop calls the proc and then it waits until
it is resumed. This enters the event loop. When the proc runs it schedules the
resumption of the `while` loop. This way, the proc is evaluated exactly once
for each iteration of the event loop.

    Benchmarked Code
    ----------------
      evaluation = Concurrently::Evaluation.current
      proc = proc{ evaluation.resume! }
      conproc = concurrent_proc{ evaluation.resume! }
      
      while elapsed_seconds < 1
        # CODE #
        await_resume!
      end
    
    Results
    -------
      # CODE #
      proc.call:                 377814 executions in 1.0000 seconds
      conproc.call:              259151 executions in 1.0000 seconds
      conproc.call_nonblock:     269870 executions in 1.0000 seconds
      conproc.call_detached:     195111 executions in 1.0000 seconds
      conproc.call_and_forget:   227178 executions in 1.0000 seconds

Explanation of the results:

* The general trend observed when only calling the procs continues: regular
  procs are the fastest and running concurrent procs in the foreground is
  faster than running them in the background.
* For calling regular procs and concurrent procs in the foreground scheduling
  is now the dominant factor. This leads to a large drop in the number of
  executions compared to just calling the procs. Since calling concurrent procs
  in the background already involved scheduling, the relative change is not as
  big for them.

You can run the benchmark yourself by running the script [perf/concurrent_proc_calls_synced_with_loop.rb][].


[perf/concurrent_proc_calls.rb]: https://github.com/christopheraue/m-ruby-concurrently/blob/master/perf/concurrent_proc_calls.rb
[perf/concurrent_proc_calls_synced_with_loop.rb]: https://github.com/christopheraue/m-ruby-concurrently/blob/master/perf/concurrent_proc_calls_synced_with_loop.rb
[Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Troubleshooting.md#A_concurrent_proc_is_scheduled_but_never_run