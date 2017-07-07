# Performance of Concurrently

The measurements were executed on an Intel i7-5820K 3.3 GHz running Linux 4.10.
Garbage collection was disabled. The benchmark runs the code in batches to
reduce the overhead of the benchmark harness.

## Calling a (Concurrent) Proc

This benchmark compares all `#call` methods of a concurrent proc and a regular
proc. The procs itself do nothing. The results represent the baseline for how
fast Concurrently is able to work. It can't get any faster than that.

    Benchmarks
    ----------
      proc.call:
        test_proc = proc{}
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call }
        end
        
      conproc.call:
        test_proc = concurrent_proc{}
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call }
        end
        
      conproc.call_nonblock:
        test_proc = concurrent_proc{}
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call_nonblock }
        end
        
      conproc.call_detached:
        test_proc = concurrent_proc{}
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call_detached }
          wait 0
        end
        
      conproc.call_and_forget:
        test_proc = concurrent_proc{}
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call_and_forget }
          wait 0
        end
        
    Results for ruby 2.4.1
    ----------------------
      proc.call:                11048400 executions in 1.0000 seconds
      conproc.call:               734000 executions in 1.0000 seconds
      conproc.call_nonblock:      857800 executions in 1.0001 seconds
      conproc.call_detached:      464800 executions in 1.0002 seconds
      conproc.call_and_forget:    721800 executions in 1.0001 seconds
    
    Results for mruby 1.3.0
    -----------------------
      proc.call:                 4771700 executions in 1.0000 seconds
      conproc.call:               362000 executions in 1.0002 seconds
      conproc.call_nonblock:      427400 executions in 1.0000 seconds
      conproc.call_detached:      188900 executions in 1.0005 seconds
      conproc.call_and_forget:    383400 executions in 1.0002 seconds

*conproc.call_detached* and *conproc.call_and_forget* call `wait 0` after each
batch so the scheduled evaluations have [a chance to run]
[Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run]. Otherwise,
their evaluations were merely scheduled and not started and concluded like it
is happening in the other cases. This makes the benchmarks comparable.

Explanation of the results:

* The difference between a regular and a concurrent proc is caused by
  concurrent procs being evaluated in a fiber and doing some bookkeeping.
* Of the two methods evaluating the proc in the foreground `#call_nonblock`
  is faster than `#call`, because the implementation of `#call` uses
  `#call_nonblock` and does a little bit more on top.
* Of the two methods evaluating the proc in the background, `#call_and_forget`
  is faster because `#call_detached` additionally creates an evaluation
  object.
* Running concurrent procs in the background is slower than running them in the
  foreground because their evaluations need to be scheduled.
* Overall, mruby is about half as fast as Ruby.

You can run the benchmark yourself by executing:

    $ rake benchmark[call_methods]


## Calling `#wait` and `#await_*` methods

This benchmark measures the number of times per second we can

* wait an amount of time,
* await readability of an IO object and
* await writability of an IO object.

Like with calling a proc doing nothing this defines what maximum performance
to expect in these cases.

    Benchmarks
    ----------
      wait:
        test_proc = proc do
          wait 0 # schedule the proc be resumed ASAP
        end
        
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call }
        end
        
      await_readable:
        test_proc = proc do |r,w|
          r.await_readable
        end
        
        batch = Array.new(100) do |idx|
          IO.pipe.tap{ |r,w| w.write '0' }
        end
        
        while elapsed_seconds < 1
          batch.each{ |*args| test_proc.call(*args) }
        end
        
      await_writable:
        test_proc = proc do |r,w|
          w.await_writable
        end
        
        batch = Array.new(100) do |idx|
          IO.pipe
        end
        
        while elapsed_seconds < 1
          batch.each{ |*args| test_proc.call(*args) }
        end
        
    Results for ruby 2.4.1
    ----------------------
      wait:                       291100 executions in 1.0001 seconds
      await_readable:             147800 executions in 1.0005 seconds
      await_writable:             148300 executions in 1.0003 seconds
    
    Results for mruby 1.3.0
    -----------------------
      wait:                       104300 executions in 1.0002 seconds
      await_readable:             132600 executions in 1.0006 seconds
      await_writable:             130500 executions in 1.0005 seconds

Explanation of the results:

* In Ruby, waiting an amount of time is much faster than awaiting readiness of
  I/O because it does not need to enter the underlying poll call.
* In mruby, awaiting readiness of I/O is actually faster than just waiting an
  amount of time. Scheduling an evaluation to resume at a specific time
  involves amongst other things inserting it into an array at the right index.
  mruby implements many Array methods in plain ruby which makes them noticeably
  slower.

You can run the benchmark yourself by executing:

    $ rake benchmark[wait_methods]


[Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Troubleshooting.md#A_concurrent_proc_is_scheduled_but_never_run