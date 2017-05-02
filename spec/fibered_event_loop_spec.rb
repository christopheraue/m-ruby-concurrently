describe FiberedEventLoop do
  subject(:instance) do
    counter = 0
    described_class.new{ iteration(counter += 1) }
  end

  describe "#start and #stop" do
    def iteration(counter)
      expect(subject).to be_running
      subject.stop counter if counter > 9
    end

    before { expect(subject).not_to be_running }
    it { expect(subject.start).to be 10 }
    after { expect(subject).not_to be_running }
  end

  describe "an iteration causing an error" do
    def iteration(counter)
      raise 'evil error' if counter == 6
      subject.stop counter if counter == 10
    end

    before { expect(instance).to receive(:trigger).with(:error,
      kind_of(RuntimeError){ |e| e.message == 'evil error' }).and_call_original }

    context "when the loop should stop and raise the error (the default)" do
      it { expect{ subject.start }.to raise_error 'evil error' }
    end

    context "when the loop should forgive the error" do
      before { subject.forgive_iteration_errors! }
      it { expect(subject.start).to be 10 }
    end
  end

  describe "#once" do
    context "when the once block executes no request of its own" do
      def iteration(counter)
        subject.once{ @once_ran1 = counter } if counter == 4
        subject.once{ @once_ran2 = counter } if counter == 4
        subject.stop :result if counter > 9
      end

      it { expect(subject.start).to be :result }
      after { expect(@once_ran1).to be 4 }
      after { expect(@once_ran2).to be 4 }
    end

    context "when the once block itself waits for a request" do
      def iteration(counter)
        case counter
        when 1 then subject.once{ @once_result = subject.await(:request) }
        when 2 then nil
        when 3 then subject.resume(:request, :result)
        else
          subject.once{ will_not_happen_because_loop_is_stopped }
          subject.stop :loop_result
        end
      end

      it { expect(subject.start).to be :loop_result }
      after { expect(@once_result).to be :result }
    end
  end

  describe "#await, #awaits? and #resume" do
    context "when waiting originates from the root fiber" do
      def iteration(counter)
        subject.resume(:result_id, counter)
      end

      it { expect(subject.await(:result_id)).to be 1 }
    end

    context "when waiting originates from an iteration fiber" do
      # The loop has to be started first to enter an iteration fiber
      def iteration(counter)
        case counter
        when 1 then @result = subject.await(:request)
        when 2 then subject.await(:another_request)
        when 3 then subject.resume(:request, :result)
        else subject.stop @result
        end
      end

      it { expect(subject.start).to be :result }
      after { expect(subject.awaits? :request).to be false }
      after { expect(subject.awaits? :another_request).to be true }
    end

    context "when resuming an iteration fiber raises an error" do
      # e.g. resuming the fiber raises a FiberError
      before do
        subject.once do
          allow(Fiber.current).to receive(:resume).and_raise FiberError, 'resume error'
          subject.await(:result_id)
        end
      end

      def iteration(counter)
        subject.resume(:result_id, :result)
        subject.stop
      end

      it { expect{ subject.start }.to raise_error IOEventLoop::CancelledError, 'resume error' }
    end

    context "when handing a result to an unknown id" do
      subject { instance.resume(:unknown, :result) }
      it { expect{ subject }.to raise_error IOEventLoop::UnknownWaitingIdError, "unknown waiting id :unknown" }
    end
  end

  describe "#cancel" do
    context "when cancelling the root fiber" do
      def iteration(counter)
        instance.cancel(:result_id, *reason)
      end
      let(:reason) { nil }

      it { expect{ subject.await(:result_id) }.to raise_error IOEventLoop::CancelledError,
        "waiting for id :result_id cancelled" }

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }

        it { expect{ subject.await(:result_id) }.to raise_error IOEventLoop::CancelledError,
          "cancel reason" }
      end
    end

    context "when cancelling an iteration fiber" do
      def iteration(counter)
        @cancel_result = instance.cancel(:result_id, *reason)
        subject.stop
      end
      let(:reason) { nil }

      before do
        subject.once do
          begin
            subject.await(:result_id)
          rescue IOEventLoop::CancelledError => e
            @result = e
          end
        end
      end

      context "when giving no explicit reason" do
        it { expect(subject.start).to be nil }
        after { expect(@result).to be_a(IOEventLoop::CancelledError).
          and having_attributes(message: "waiting for id :result_id cancelled") }
        after { expect(@cancel_result).to be :cancelled }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }

        it { expect(subject.start).to be nil }
        after { expect(@result).to be_a(IOEventLoop::CancelledError).
          and having_attributes(message: "cancel reason") }
        after { expect(@cancel_result).to be :cancelled }
      end
    end

    context "when cancelling a fiber with an unknown id" do
      subject { instance.resume(:unknown, :result) }
      it { expect{ subject }.to raise_error IOEventLoop::UnknownWaitingIdError, "unknown waiting id :unknown" }
    end
  end

  describe "#watch_events" do
    subject { instance.watch_events(object, :event) }

    let(:object) { Object.new.extend CallbacksAttachable }

    it { is_expected.to be_a(IOEventLoop::EventWatcher).and having_attributes(loop: instance,
      subject: object, event: :event)}
  end
end
