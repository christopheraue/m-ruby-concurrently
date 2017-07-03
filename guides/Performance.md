# Performance of Concurrently

The measurements were executed on an Intel i7-5820K 3.3 GHz running Linux 4.10.
Garbage collection was disabled.

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
    
    Results for ruby 2.4.1
    ----------------------
      # CODE #
      proc.call:                5266268 executions in 1.0000 seconds
      conproc.call:              636313 executions in 1.0000 seconds
      conproc.call_nonblock:     760222 executions in 1.0000 seconds
      conproc.call_detached:     290855 executions in 1.0000 seconds
      conproc.call_and_forget:   325831 executions in 1.0000 seconds
    
    Results for mruby 1.3.0
    -----------------------
      # CODE #
      proc.call:                1718814 executions in 1.0000 seconds
      conproc.call:              338579  executions in 1.0000 seconds
      conproc.call_nonblock:     368053  executions in 1.0000 seconds
      conproc.call_detached:     273152  executions in 1.0000 seconds
      conproc.call_and_forget:   385587  executions in 1.0000 seconds

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

You can run the benchmark yourself by running:

    $ rake benchmark[calls]


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
    
    Results for ruby 2.4.1
    ----------------------
      # CODE #
      conproc.call:               76395 executions in 1.0000 seconds
      conproc.call_nonblock:     107481 executions in 1.0000 seconds
      conproc.call_detached:     118984 executions in 1.0000 seconds
      conproc.call_and_forget:   123408 executions in 1.0000 seconds
    
    Results for mruby 1.3.0
    -----------------------
      # CODE #
      conproc.call:               30003   executions in 1.0000 seconds
      conproc.call_nonblock:      38709   executions in 1.0000 seconds
      conproc.call_detached:      47200   executions in 1.0000 seconds
      conproc.call_and_forget:    49503   executions in 1.0000 seconds

Explanation of the results:

* Because scheduling is now the dominant factor, there is a large drop in the
  number of executions compared to just calling the procs. This makes the
  number of executions when calling the proc in a non-blocking way comparable.
* Calling the proc in a blocking manner with `#call` is costly. A lot of time
  is spend waiting for the result.

You can run the benchmark yourself by running:

    $ rake benchmark[calls_awaiting]


## Scheduling (Concurrent) Procs and Evaluating Them in Batches

Additional to waiting inside a proc, it calls the proc 100 times at once. All
100 evaluations will then be evaluated in one batch during the next iteration
of the event loop.

This is a simulation for a server receiving multiple messages during one
iteration of the event loop and processing all of them in one go.

    Benchmarked Code
    ----------------
      conproc = concurrent_proc{ wait 0 }
      
      while elapsed_seconds < 1
        100.times{ # CODE # }
        wait 0 # to enter the event loop
      end
    
    Results for ruby 2.4.1
    ----------------------
      # CODE #
      conproc.call:               77700 executions in 1.0008 seconds
      conproc.call_nonblock:     198800 executions in 1.0001 seconds
      conproc.call_detached:     197800 executions in 1.0003 seconds
      conproc.call_and_forget:   207700 executions in 1.0001 seconds
    
    Results for mruby 1.3.0
    -----------------------
      # CODE #
      conproc.call:               30300   executions in 1.0024 seconds
      conproc.call_nonblock:      74700   executions in 1.0013 seconds
      conproc.call_detached:      76600   executions in 1.0003 seconds
      conproc.call_and_forget:    81900   executions in 1.0013 seconds

Explanation of the results:

* `#call` does not profit from batching due to is synchronizing nature.
* The other methods show an increased throughput compared to running just a
  single evaluation per event loop iteration.

The result of this benchmark is the upper bound for how many concurrent
evaluations Concurrently is able to run per second. The number of executions
does not change much with a varying batch size. Larger batches (e.g. 200+)
gradually start to get a bit slower. A batch of 1000 evaluations still leads to
around 160k executions in Ruby and around 65k in mruby.

You can run the benchmark yourself by running:

    $ rake benchmark[calls_awaiting,100]


[Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Troubleshooting.md#A_concurrent_proc_is_scheduled_but_never_run