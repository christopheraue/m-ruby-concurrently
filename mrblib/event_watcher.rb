module Concurrently
  class EventWatcher
    def initialize(loop, subject, event, opts = {})
      @loop = loop
      @subject = subject
      @event = event
      @max_events = opts.fetch(:max_events, Float::INFINITY)
      @received = 0
      
      @results = []
      @callback = @subject.on(@event) do |_,result|
        @results.unshift result
        cancel "only interested in #{@max_events} event(s)" if (@received += 1) >= @max_events
      end
    end

    attr_reader :loop, :subject, :event, :received

    def await
      @results.pop or begin
        raise CancelledError, @cancel_reason if @cancel_reason
        @loop.await_event(@subject, @event)
        await
      end
    end

    def pending?
      not @results.empty?
    end

    def cancelled?
      instance_variable_defined? :@cancel_reason
    end

    def cancel(reason)
      raise Error, 'already cancelled' if @cancel_reason

      @cancel_reason = reason
      @callback.cancel

      :cancelled
    end
  end
end