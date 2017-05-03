describe IOEventLoop::Timer do
  subject(:instance) { described_class.new(seconds, callback) }

  let(:seconds) { 1.5 }
  let(:callback) { proc{} }

  shared_context "for a running timer" do |seconds:, offset: 0|
    after { expect(instance.cancelled?).to be false }
    after { expect(instance.seconds).to be seconds }
    after { expect(instance.waiting_time).to be_within(0.02).of(offset + seconds) }
    after { expect(instance.timeout_time).to be_within(0.02).of(IOEventLoop::WallClock.now + offset + seconds) }
  end

  shared_context "for a cancelled timer" do |seconds:|
    after { expect(instance.cancelled?).to be true }
    after { expect(instance.seconds).to be seconds }
    after { expect(instance.waiting_time).to be nil }
    after { expect(instance.timeout_time).to be_within(0.02).of(IOEventLoop::WallClock.now + seconds) }
  end

  describe "Initialization" do
    context "when called with another waiting time" do
      let(:seconds) { 2.4 }
      it { is_expected.not_to raise_error }
      include_context "for a running timer", seconds: 2.4
    end

    context "when given a callback" do
      let(:callback) { proc{} }
      it { is_expected.not_to raise_error }
      include_context "for a running timer", seconds: 1.5
    end

    context "when given no callback" do
      let(:callback) { nil }
      it { is_expected.to raise_error IOEventLoop::Error, 'no block given' }
    end
  end

  describe "#trigger" do
    subject { instance.trigger }

    context "when not cancelled" do
      before { expect(callback).to receive(:call) }
      it { is_expected.to be true }
      include_context "for a cancelled timer", seconds: 1.5
    end

    context "when cancelled" do
      before { instance.cancel }
      it { is_expected.to be false }
    end
  end

  describe "#cancel" do
    subject { instance.cancel }

    it { is_expected.to be true }
    include_context "for a cancelled timer", seconds: 1.5
  end

  describe "#repeat" do
    subject { instance.repeat }

    it { is_expected.to be true }
    include_context "for a running timer", seconds: 1.5, offset: 1.5
  end

  describe "#inspect" do
    subject { instance.inspect }

    context "when running" do
      before { allow(instance).to receive(:waiting_time).and_return(1.79854) }
      it { is_expected.to eq "#<#{described_class}:0x#{'%014x' % instance.__id__} waits another 1.799 seconds>" }
    end

    context "when cancelled" do
      before { instance.cancel }
      it { is_expected.to eq "#<#{described_class}:0x#{'%014x' % instance.__id__} CANCELED>" }
    end
  end
end
