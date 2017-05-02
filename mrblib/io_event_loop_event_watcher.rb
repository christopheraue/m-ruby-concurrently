class IOEventLoop
  class EventWatcher
    def initialize(loop, subject, event, opts = {})
      @loop = loop
      @subject = subject
      @event = event
      @max_events = opts.fetch(:max_events, Float::INFINITY)
      @received = 0
      
      @results = []
      @callback = @subject.on(@event) do |_,result|
        if @loop.awaits? __id__
          @loop.resume __id__, result
        else
          @results.unshift result
        end

        cancel "only interested in #{@max_events} event(s)" if (@received += 1) >= @max_events
      end
    end

    attr_reader :loop, :subject, :event, :received

    def await(*args)
      # Pass potential args along to loop#await. This allows us to use
      # a timeout for this method when using IOEventLoop.

      @results.pop or begin
        raise CancelledError, @cancel_reason if @cancel_reason
        raise EventWatcherError, 'already waiting' if @loop.awaits? __id__
        @loop.await(__id__, *args)
      end
    end

    def pending?
      not @results.empty?
    end

    def cancelled?
      instance_variable_defined? :@cancel_reason
    end

    def cancel(reason)
      raise EventWatcherError, 'already cancelled' if @cancel_reason

      @cancel_reason = reason
      @callback.cancel
      @loop.cancel __id__, reason if @loop.awaits? __id__

      :cancelled
    end
  end
end