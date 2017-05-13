describe IOEventLoop do
  subject(:instance) { IOEventLoop.new }

  describe "#lifetime" do
    subject { instance.lifetime }
    let!(:creation_time) { instance; Time.now.to_f }
    before { instance.wait 0.001 }
    it { is_expected.to be_within(0.0001).of(Time.now.to_f - creation_time) }
  end

  describe "#watch_events" do
    subject { instance.watch_events(object, :event) }

    let(:object) { Object.new.extend CallbacksAttachable }

    it { is_expected.to be_a(IOEventLoop::EventWatcher).and having_attributes(loop: instance,
      subject: object, event: :event)}
  end
end