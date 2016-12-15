describe IOEventLoop::Timer do
  subject(:instance) { described_class.new(seconds, repeat: repeat, start_time: start_time, &callback) }

  let(:seconds) { 1.5 }
  let(:repeat) { false }
  let(:start_time) { IOEventLoop::WallClock.now }
  let(:callback) { proc{} }

  shared_context "for a running timer" do |seconds:, repeat: false|
    after { expect(instance.canceled?).to be false }
    after { expect(instance.seconds).to be seconds }
    after { expect(instance.waiting_time).to be_within(0.02).of((start_time - IOEventLoop::WallClock.now) + seconds) }
    after { expect(instance.timeout_time).to be_within(0.02).of(start_time + seconds) }
    after { expect(instance.repeats?).to be repeat }
  end

  shared_context "for a canceled timer" do |seconds:, repeat: false|
    after { expect(instance.canceled?).to be true }
    after { expect(instance.seconds).to be seconds }
    after { expect(instance.waiting_time).to be nil }
    after { expect(instance.timeout_time).to be_within(0.02).of(start_time + seconds) }
    after { expect(instance.repeats?).to be repeat }
  end

  describe "Initialization" do
    context "when called with another waiting time" do
      let(:seconds) { 2.4 }
      it { is_expected.not_to raise_error }
      include_context "for a running timer", seconds: 2.4
    end

    context "when called with another repeat setting" do
      let(:repeat) { true }
      it { is_expected.not_to raise_error }
      include_context "for a running timer", seconds: 1.5, repeat: true
    end

    context "when called with a custom start time" do
      let(:start_time) { 12.24 }
      it { is_expected.not_to raise_error }
      include_context "for a running timer", seconds: 1.5
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

    context "when canceled" do
      before { instance.cancel }
      it { is_expected.to raise_error IOEventLoop::Error, 'timer canceled' }
    end

    context "when one-shot" do
      let(:repeat) { false }
      before { expect(callback).to receive(:call) }
      it { is_expected.to be true }
      include_context "for a canceled timer", seconds: 1.5
    end

    context "when recurring" do
      let(:repeat) { true }
      before { expect(callback).to receive(:call) }
      before { @start_time = IOEventLoop::WallClock.now }
      it { is_expected.to be true }
      before { @start_time = instance.timeout_time  }
      def start_time; @start_time end
      include_context "for a running timer", seconds: 1.5, repeat: true
    end
  end

  describe "#cancel" do
    subject { instance.cancel }

    it { is_expected.to be true }
    include_context "for a canceled timer", seconds: 1.5
  end

  describe "#inspect" do
    subject { instance.inspect }

    context "when running" do
      before { allow(instance).to receive(:waiting_time).and_return(1.79854) }
      it { is_expected.to eq "#<#{described_class}:0x#{'%014x' % instance.__id__} waits another 1.799 seconds>" }
    end

    context "when canceled" do
      before { instance.cancel }
      it { is_expected.to eq "#<#{described_class}:0x#{'%014x' % instance.__id__} CANCELED>" }
    end
  end
end
