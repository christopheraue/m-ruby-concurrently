# Performance of Concurrently

The measurements were executed on an Intel i7-5820K 3.3 GHz running Linux 4.10.
Garbage collection was disabled. The benchmark runs the code in batches to
reduce the overhead of the benchmark harness.

## Mere Invocation of Concurrent Procs

This benchmark compares all call methods of a [concurrent proc][Concurrently::Proc] 
and a regular proc. The procs itself do nothing. The results represent the
baseline for how fast Concurrently is able to work. It can't get any faster
than that.

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
      proc.call:                11521800 executions in 1.0000 seconds
      conproc.call:               756000 executions in 1.0001 seconds
      conproc.call_nonblock:      881800 executions in 1.0001 seconds
      conproc.call_detached:      443500 executions in 1.0001 seconds
      conproc.call_and_forget:    755600 executions in 1.0001 seconds
    
    Results for mruby 1.3.0
    -----------------------
      proc.call:                 5801400 executions in 1.0000 seconds
      conproc.call:               449100 executions in 1.0002 seconds
      conproc.call_nonblock:      523400 executions in 1.0000 seconds
      conproc.call_detached:      272500 executions in 1.0000 seconds
      conproc.call_and_forget:    490500 executions in 1.0001 seconds

*conproc.call_detached* and *conproc.call_and_forget* call `wait 0` after each
batch so the scheduled evaluations have [a chance to run]
[Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run]. Otherwise,
their evaluations were merely scheduled and not started and concluded like it
is happening in the other cases. This makes the benchmarks comparable.

Explanation of the results:

* The difference between a regular and a concurrent proc is caused by
  concurrent procs being evaluated in a fiber and doing some bookkeeping.
* Of the two methods evaluating the proc in the foreground
  [Concurrently::Proc#call_nonblock][] is faster than [Concurrently::Proc#call][],
  because the implementation of [Concurrently::Proc#call][] uses
  [Concurrently::Proc#call_nonblock][] and does a little bit more on top.
* Of the two methods evaluating the proc in the background,
  [Concurrently::Proc#call_and_forget][] is faster because
  [Concurrently::Proc#call_detached][] additionally creates an evaluation
  object.
* Running concurrent procs in the background is slower than running them in the
  foreground because their evaluations need to be scheduled.
* Overall, mruby is about half as fast as Ruby.

You can run this benchmark yourself by executing:

    $ rake benchmark[call_methods]


## Mere Waiting

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
      wait:                       331300 executions in 1.0001 seconds
      await_readable:             152500 executions in 1.0001 seconds
      await_writable:             150700 executions in 1.0001 seconds
    
    Results for mruby 1.3.0
    -----------------------
      wait:                       160700 executions in 1.0004 seconds
      await_readable:             176700 executions in 1.0005 seconds
      await_writable:             177700 executions in 1.0003 seconds

Explanation of the results:

* In Ruby, waiting an amount of time is much faster than awaiting readiness of
  I/O because it does not need to enter the underlying poll call.
* In mruby, awaiting readiness of I/O is actually faster than just waiting an
  amount of time. Scheduling an evaluation to resume at a specific time
  involves amongst other things inserting it into an array at the right index.
  mruby implements many Array methods in plain ruby which makes them noticeably
  slower.

You can run this benchmark yourself by executing:

    $ rake benchmark[wait_methods]


## Waiting Inside Concurrent Procs

Concurrent procs show different performance depending on how they are called
and if their evaluation needs to wait or not. This benchmark explores these
differences and serves as a guide which call method provides the best
performance in these scenarios.

    Benchmarks
    ----------
      call:
        test_proc = concurrent_proc{}
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call }
          # Concurrently::Proc#call already synchronizes the results of evaluations
        end
        
      call_nonblock:
        test_proc = concurrent_proc{}
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call_nonblock }
        end
        
      call_detached:
        test_proc = concurrent_proc{}
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          evaluations = batch.map{ test_proc.call_detached }
          evaluations.each{ |evaluation| evaluation.await_result }
        end
        
      call_and_forget:
        test_proc = concurrent_proc{}
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call_and_forget }
          wait 0
        end
        
      waiting call:
        test_proc = concurrent_proc{ wait 0 }
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call }
          # Concurrently::Proc#call already synchronizes the results of evaluations
        end
        
      waiting call_nonblock:
        test_proc = concurrent_proc{ wait 0 }
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          evaluations = batch.map{ test_proc.call_nonblock }
          evaluations.each{ |evaluation| evaluation.await_result }
        end
        
      waiting call_detached:
        test_proc = concurrent_proc{ wait 0 }
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          evaluations = batch.map{ test_proc.call_detached }
          evaluations.each{ |evaluation| evaluation.await_result }
        end
        
      waiting call_and_forget:
        test_proc = concurrent_proc{ wait 0 }
        batch = Array.new(100)
        
        while elapsed_seconds < 1
          batch.each{ test_proc.call_and_forget }
          wait 0
        end
        
    Results for ruby 2.4.1
    ----------------------
      call:                       753800 executions in 1.0000 seconds
      call_nonblock:              913400 executions in 1.0000 seconds
      call_detached:              418700 executions in 1.0001 seconds
      call_and_forget:            748800 executions in 1.0001 seconds
      waiting call:                89400 executions in 1.0001 seconds
      waiting call_nonblock:      198800 executions in 1.0001 seconds
      waiting call_detached:      199600 executions in 1.0004 seconds
      waiting call_and_forget:    225300 executions in 1.0001 seconds
    
    Results for mruby 1.3.0
    -----------------------
      call:                       444200 executions in 1.0002 seconds
      call_nonblock:              525300 executions in 1.0001 seconds
      call_detached:              232600 executions in 1.0003 seconds
      call_and_forget:            464500 executions in 1.0000 seconds
      waiting call:                60100 executions in 1.0004 seconds
      waiting call_nonblock:       95400 executions in 1.0004 seconds
      waiting call_detached:      102100 executions in 1.0005 seconds
      waiting call_and_forget:    118500 executions in 1.0005 seconds

`wait 0` is used as a stand in for all wait methods. Measurements of concurrent
procs doing nothing are included for comparision.

Explanation of the results:

* [Concurrently::Proc#call][] is the slowest if the concurrent proc needs to
  wait. Immediately synchronizing the result for each and every evaluation
  introduces a noticeable overhead.
* [Concurrently::Proc#call_nonblock][] and [Concurrently::Proc#call_detached][]
  perform similarly. When started [Concurrently::Proc#call_nonblock][] skips
  some work related to waiting that [Concurrently::Proc#call_detached][] is
  already doing. Now, when the concurrent proc actually waits
  [Concurrently::Proc#call_nonblock][] needs to make up for this skipped work.
  This puts its performance in the same region as the one of
  [Concurrently::Proc#call_detached][].
* [Concurrently::Proc#call_and_forget][] is the fastest way to wait inside a
  concurrent proc. It comes at the cost that the result of the evaluation
  cannot be returned.

To find the fastest way to evaluate a proc it has to be considered if the proc
does or does not wait most of the time and if its result is needed:

<table>
  <tr>
    <th></th>
    <th>result needed</th>
    <th>result not needed</th>
  </tr>
  <tr>
    <th>waits almost always</th>
    <td><code>#call_nonblock</code> or<br/><code>#call_detached</code></td>
    <td><code>#call_and_forget</code></td>
  </tr>
  <tr>
    <th>waits almost never</th>
    <td><code>#call_nonblock</code></td>
    <td><code>#call_nonblock</code></td>
  </tr>
</table>

[Kernel#concurrently][] calls [Concurrently::Proc#call_detached][] under the
hood as a reasonable default. [Concurrently::Proc#call_detached][] has the
easiest interface and provides good performance especially in the most common
use case of Concurrently: waiting for an event to happen.
[Concurrently::Proc#call_nonblock][] and [Concurrently::Proc#call_and_forget][]
are there to squeeze out more performance in some edge cases.

You can run this benchmark yourself by executing:

    $ rake benchmark[call_methods_waiting]


[Troubleshooting/A_concurrent_proc_is_scheduled_but_never_run]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Troubleshooting.md#A_concurrent_proc_is_scheduled_but_never_run
[Concurrently::Proc]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc
[Concurrently::Proc#call]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call-instance_method
[Concurrently::Proc#call_nonblock]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_nonblock-instance_method
[Concurrently::Proc#call_detached]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_detached-instance_method
[Concurrently::Proc#call_and_forget]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_and_forget-instance_method
[Kernel#concurrently]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrently-instance_method