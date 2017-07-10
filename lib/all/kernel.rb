# @api public
#
# Concurrently adds a few methods to `Kernel` which makes them available
# for every object.
module Kernel
  # @!method concurrently(*args, &block)
  #
  # Executes code concurrently in the background.
  #
  # This is a shortcut for {Concurrently::Proc#call_detached}.
  #
  # @return [nil]
  #
  # @example
  #   concurrently(a,b,c) do |a,b,c|
  #     # ...
  #   end
  #
  # @since 1.0.0
  private def concurrently(*args)
    # Concurrently::Proc.new claims the method's block just like Proc.new does
    Concurrently::Proc.new.call_detached *args
  end

  # @!method concurrent_proc(&block)
  #
  # Creates a concurrent proc to execute code concurrently.
  #
  # This a shortcut for {Concurrently::Proc}.new(&block) like `proc(&block)`
  # is a shortcut for `Proc.new(&block)`.
  #
  # @return [Concurrently::Proc]
  #
  # @example
  #   wait_proc = concurrent_proc do |seconds|
  #     wait seconds
  #   end
  #
  #   wait_proc.call 2 # waits 2 seconds and then resumes
  #
  # @since 1.0.0
  private def concurrent_proc(evaluation_class = Concurrently::Proc::Evaluation)
    # Concurrently::Proc.new claims the method's block just like Proc.new does
    Concurrently::Proc.new(evaluation_class)
  end

  # @note The exclamation mark in its name stands for: Watch out!
  #   This method needs to be complemented with a later call to
  #   {Concurrently::Evaluation#resume!}.
  #
  # Suspends the current evaluation until it is resumed manually. It can be
  # used inside and outside of concurrent procs.
  #
  # It needs to be complemented with a later call of {Concurrently::Evaluation#resume!}.
  #
  # @param [Hash] opts
  # @option opts [Numeric] :within maximum time to wait *(defaults to: Float::INFINITY)*
  # @option opts [Object] :timeout_result result to return in case of an exceeded
  #   waiting time *(defaults to raising {Concurrently::Evaluation::TimeoutError})*
  #
  # @return [Object] the result {Concurrently::Evaluation#resume!} is called
  #   with.
  # @raise [Concurrently::Evaluation::TimeoutError] if a given maximum waiting time
  #   is exceeded and no custom timeout result is given.
  #
  # @example Waiting inside a concurrent proc
  #   # Control flow is indicated by (N)
  #
  #   # (1)
  #   evaluation = concurrent_proc do
  #     # (4)
  #     await_resume!
  #     # (7)
  #   end.call_nonblock
  #
  #   # (2)
  #   concurrently do
  #     # (5)
  #     puts "I'm running while the outside is waiting!"
  #     evaluation.resume! :result
  #     # (6)
  #   end
  #
  #   # (3)
  #   evaluation.await_result # => :result
  #   # (8)
  #
  # @example Waiting outside a concurrent proc
  #   # Control flow is indicated by (N)
  #
  #   evaluation = Concurrently::Evaluation.current
  #
  #   # (1)
  #   concurrently do
  #     # (3)
  #     puts "I'm running while the outside is waiting!"
  #     evaluation.resume! :result
  #     # (4)
  #   end
  #
  #   # (2)
  #   await_resume! # => :result
  #   # (5)
  #
  # @example Waiting with a timeout
  #   await_resume! within: 1
  #   # => raises a TimeoutError after 1 second
  #
  # @example Waiting with a timeout and a timeout result
  #   await_resume! within: 0.1, timeout_result: false
  #   # => returns false after 0.1 seconds
  #
  # @since 1.0.0
  private def await_resume!(opts = {})
    event_loop = Concurrently::EventLoop.current
    run_queue = event_loop.run_queue
    evaluation = run_queue.current_evaluation

    if seconds = opts[:within]
      timeout_result = opts.fetch(:timeout_result, Concurrently::Evaluation::TimeoutError)
      run_queue.schedule_deferred(evaluation, seconds, timeout_result)
    end

    evaluation.instance_variable_set :@waiting, true
    result = case evaluation
    when Concurrently::Proc::Evaluation
      # Yield back to the event loop fiber or the evaluation evaluating this one.
      # Pass along itself to indicate it is not yet fully evaluated.
      Fiber.yield evaluation
    else
      event_loop.fiber.resume
    end
    evaluation.instance_variable_set :@waiting, false

    # If result is this very evaluation it means this evaluation has been evaluated
    # prematurely.
    if evaluation.fiber == result
      run_queue.cancel evaluation # in case the evaluation has already been scheduled to resume
      raise Concurrently::Proc::Evaluation::Cancelled, '', []
    elsif Concurrently::Evaluation::TimeoutError == result
      raise result, "evaluation timed out after #{seconds} second(s)"
    else
      result
    end
  ensure
    if seconds
      run_queue.cancel evaluation
    end
  end

  # Suspends the current evaluation for the given number of seconds. It can be
  # used inside and outside of concurrent procs.
  #
  # While waiting, the code jumps to the event loop and executes other
  # concurrent procs that are ready to run in the meantime.
  #
  # @return [true]
  #
  # @example Waiting inside a concurrent proc
  #   # Control flow is indicated by (N)
  #
  #   # (1)
  #   wait_proc = concurrent_proc do |seconds|
  #     # (4)
  #     wait seconds
  #     # (6)
  #     :waited
  #   end
  #
  #   # (2)
  #   concurrently do
  #     # (5)
  #     puts "I'm running while the other proc is waiting!"
  #   end
  #
  #   # (3)
  #   wait_proc.call 1 # => :waited
  #   # (7)
  #
  # @example Waiting outside a concurrent proc
  #   # Control flow is indicated by (N)
  #
  #   # (1)
  #   concurrently do
  #     # (3)
  #     puts "I'm running while the outside is waiting!"
  #   end
  #
  #   # (2)
  #   wait 1
  #   # (4)
  #
  # @since 1.0.0
  private def wait(seconds)
    run_queue = Concurrently::EventLoop.current.run_queue
    evaluation = run_queue.current_evaluation
    run_queue.schedule_deferred(evaluation, seconds, true)
    await_resume!
  ensure
    run_queue.cancel evaluation
  end

  # Waits for the first in a list of evaluations to be concluded.
  #
  # @overload await_fastest(evaluation0, evaluation1, *more_evaluations, opts = {})
  #
  #   @param [Concurrently::Proc::Evaluation] evaluation0
  #   @param [Concurrently::Proc::Evaluation] evaluation1
  #   @param [Concurrently::Proc::Evaluation] *more_evaluations
  #   @param [Hash] opts
  #   @option opts [Numeric] :within maximum time to wait *(defaults to: Float::INFINITY)*
  #   @option opts [Object] :timeout_result result to return in case of an exceeded
  #     waiting time *(defaults to raising {Concurrently::Evaluation::TimeoutError})*
  #
  # @return [Concurrently::Proc::Evaluation] the evaluation been concluded first
  # @raise [Concurrently::Evaluation::TimeoutError] if a given maximum waiting time
  #   is exceeded and no custom timeout result is given.
  #
  # @example
  #   evaluation0 = concurrently{ wait 2 }
  #   evaluation1 = concurrently{ wait 1 }
  #
  #   await_fastest(evaluation0, evaluation1) # => evaluation1
  #
  # @example Waiting with a timeout
  #   evaluation0 = concurrently{ wait 2 }
  #   evaluation1 = concurrently{ wait 1 }
  #
  #   await_fastest(evaluation0, evaluation1, within: 0.1)
  #   # => raises a TimeoutError after 0.1 seconds
  #
  # @example Waiting with a timeout and a timeout result
  #   evaluation0 = concurrently{ wait 2 }
  #   evaluation1 = concurrently{ wait 1 }
  #
  #   await_fastest(evaluation0, evaluation1, within: 0.1, timeout_result: false)
  #   # => returns false after 0.1 seconds
  #
  # @since 1.1.0
  private def await_fastest(eval0, eval1, *evaluations)
    opts = (evaluations.last.is_a? Hash) ? evaluations.pop : {}
    evaluations.unshift eval0, eval1

    if concluded = evaluations.find(&:concluded?)
      concluded
    else
      begin
        curr_eval = Concurrently::Evaluation.current
        evaluations.each{ |e| e.instance_eval{ @awaiting_result.store curr_eval, self } }
        await_resume! opts
      ensure
        evaluations.each{ |e| e.instance_eval{ @awaiting_result.delete curr_eval } }
      end
    end
  end
end