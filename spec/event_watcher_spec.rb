describe IOEventLoop::EventWatcher do
  let!(:instance) { described_class.new loop, object, event, *opts }

  let(:loop) { IOEventLoop.new }
  let(:object) { Object.new.extend CallbacksAttachable }
  let(:event) { :event }
  let(:opts) { nil }

  it { expect(instance.loop).to be loop }
  it { expect(instance.subject).to be object }
  it { expect(instance.event).to be :event }
  it { expect(instance.received).to be 0 }
  it { expect(instance).not_to be_cancelled }

  describe "#await" do
    subject { instance.await }

    let(:event_result) { :event_result }
    after { expect(instance.pending?).to be false }

    context "when the event has already happened since creating the watcher" do
      before { object.trigger(event, event_result) }

      before { expect(instance.pending?).to be true }
      it { is_expected.to be event_result }

      context "when already happened two times" do
        before { object.trigger(event, :event_result2) }
        before { expect(instance.pending?).to be true }
        before { instance.await }
        it { is_expected.to be :event_result2 }

        context "when we only want to watch for one event" do
          let(:opts) { [max_events: 1] }
          it { is_expected.to raise_error IOEventLoop::CancelledError,
            'only interested in 1 event(s)' }
        end
      end
    end

    context "when the event happens later" do
      before { loop.concurrently{ loop.wait(0.0001); object.trigger(event, event_result) } }
      it { is_expected.to be event_result }
      after { expect(instance.received).to be 1 }
    end

    context "when the watcher has already been cancelled" do
      before { instance.cancel('cancel reason') }
      it { is_expected.to raise_error IOEventLoop::CancelledError, 'cancel reason' }
    end
  end

  describe "#cancel" do
    subject { instance.cancel('cancel reason') }

    it { is_expected.to be :cancelled }
    after { expect(instance.cancelled?).to be true }

    context "when the watcher is cancelled after starting to wait" do
      before { loop.concurrently{ subject }.result }
      it { expect{ instance.await }.to raise_error IOEventLoop::CancelledError, 'cancel reason' }
    end

    context "when the watched has already been cancelled" do
      before { instance.cancel('cancel reason') }
      it { is_expected.to raise_error IOEventLoop::EventWatcherError, 'already cancelled' }
    end
  end
end