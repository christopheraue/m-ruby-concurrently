describe Concurrently::EventWatcher do
  let!(:instance) { described_class.new object, event, *opts }

  let(:object) { Object.new.extend CallbacksAttachable }
  let(:event) { :event }
  let(:opts) { nil }

  it { expect(instance.subject).to be object }
  it { expect(instance.event).to be :event }
  it { expect(instance.received).to be 0 }
  it { expect(instance).not_to be_cancelled }

  describe "#await" do
    subject { instance.await wait_options }

    let(:wait_options) { {} }
    let(:result) { :result }
    after { expect(instance.pending?).to be false }

    context "when the event has already happened since creating the watcher" do
      before { object.trigger(event, result) }

      before { expect(instance.pending?).to be true }
      it { is_expected.to be result }

      context "when already happened two times" do
        before { object.trigger(event, :event_result2) }
        before { expect(instance.pending?).to be true }
        before { instance.await }
        it { is_expected.to be :event_result2 }

        context "when we only want to watch for one event" do
          let(:opts) { [max_events: 1] }
          it { is_expected.to raise_error Concurrently::EventWatcher::CancelledError,
            'only interested in 1 event(s)' }
        end
      end
    end

    context "when the event happens later" do
      let(:evaluation_time) { 0.001 }

      context "when it is allowed to wait forever" do
        before { concurrently do
          wait evaluation_time
          object.trigger event, result
        end }
        it { is_expected.to eq result }
      end

      context "when limiting the wait time" do
        let(:wait_options) { { within: timeout_time, timeout_result: timeout_result } }
        let(:timeout_result) { :timeout_result }

        context "when the result arrives in time" do
          let(:timeout_time) { 2*evaluation_time }

          before { concurrently do
            wait evaluation_time
            object.trigger event, result
          end }

          let!(:after_timeout) { concurrent_proc{ wait timeout_time }.call_detached }

          it { is_expected.to eq result }

          # will raise an error if the timeout is not cancelled
          after { expect{ after_timeout.await_result }.not_to raise_error }
        end

        context "when the evaluation of the result is too slow" do
          let(:timeout_time) { 0.0 }

          context "when no timeout result is given" do
            before { wait_options.delete :timeout_result }
            it { is_expected.to raise_error Concurrently::Proc::TimeoutError, "evaluation timed out after #{wait_options[:within]} second(s)" }
          end

          context "when a timeout result is given" do
            let(:timeout_result) { :timeout_result }
            it { is_expected.to be :timeout_result }
          end
        end
      end
    end

    context "when the watcher has already been cancelled" do
      before { instance.cancel('cancel reason') }
      it { is_expected.to raise_error Concurrently::EventWatcher::CancelledError, 'cancel reason' }
    end
  end

  describe "#cancel" do
    subject { instance.cancel('cancel reason') }

    it { is_expected.to be :cancelled }
    after { expect(instance.cancelled?).to be true }

    context "when the watcher is cancelled after starting to wait" do
      before { concurrent_proc{ subject }.call }
      it { expect{ instance.await }.to raise_error Concurrently::EventWatcher::CancelledError, 'cancel reason' }
    end

    context "when the watched has already been cancelled" do
      before { instance.cancel('cancel reason') }
      it { is_expected.to raise_error Concurrently::EventWatcher::Error, 'already cancelled' }
    end
  end
end