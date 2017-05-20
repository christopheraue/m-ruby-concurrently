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
    subject { instance.await }

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
      it_behaves_like "awaiting the result of a deferred evaluation" do
        let(:wait_proc) { proc{ instance.await wait_options } }

        def resume
          object.trigger event, result
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