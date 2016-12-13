describe AggregatedTimers::Timer do
  subject(:instance) { described_class.new(1.5, repeat: repeat, &callback) }

  let(:repeat) { false }
  let(:callback) { proc{} }

  shared_context "for a running timer" do |seconds:, repeat: false|
    let(:start_time) { AggregatedTimers::WallClock.now } unless method_defined? :start_time
    after { expect(instance.canceled?).to be false }
    after { expect(instance.seconds).to be seconds }
    after { expect(instance.waiting_time).to be_within(0.02).of((start_time - AggregatedTimers::WallClock.now) + seconds) }
    after { expect(instance.timeout_time).to be_within(0.02).of(start_time + seconds) }
    after { expect(instance.repeats?).to be repeat }
  end

  shared_context "for a canceled timer" do
    after { expect(instance.canceled?).to be true }
    after { expect(instance.seconds).to be nil }
    after { expect(instance.timeout_time).to be nil }
    after { expect(instance.waiting_time).to be nil }
    after { expect(instance.repeats?).to be nil }
  end

  describe "Initialization" do
    context "when given a callback" do
      let(:callback) { proc{} }
      it { is_expected.not_to raise_error }
      include_context "for a running timer", seconds: 1.5
    end

    context "when given no callback" do
      let(:callback) { nil }
      it { is_expected.to raise_error AggregatedTimers::Error, 'no block given' }
    end
  end

  describe "#restart" do
    subject { instance.restart(seconds, repeat: repeat, start_time: start_time, &callback) }

    let(:seconds) { 1 }
    let(:repeat) { false }
    let(:start_time) { AggregatedTimers::WallClock.now }
    let(:callback) { proc{} }

    let!(:instance) { described_class.new(1, repeat: false, &init_callback) }
    let(:init_callback) { proc{} }

    before { expect(instance).to receive(:trigger_event).with(:restart, instance).and_call_original }

    context "when called without arguments" do
      subject { instance.restart }
      it { is_expected.to be true }
      include_context "for a running timer", seconds: 1
    end

    context "when called with a changed waiting time" do
      context "when given a number" do
        let(:seconds) { 2.4 }
        it { is_expected.to be true }
        include_context "for a running timer", seconds: 2.4
      end

      context "when given nil" do
        let(:seconds) { nil }
        it { is_expected.to be true }
        include_context "for a running timer", seconds: 1
      end
    end

    context "when called with a changed repeat setting" do
      context "when given a boolean" do
        let(:repeat) { true }
        it { is_expected.to be true }
        include_context "for a running timer", seconds: 1, repeat: true
      end

      context "when given nil" do
        let(:repeat) { nil }
        it { is_expected.to be true }
        include_context "for a running timer", seconds: 1
      end
    end

    context "when called with a custom start time" do
      let(:start_time) { 12.24 }
      it { is_expected.to be true }
      include_context "for a running timer", seconds: 1
    end

    context "when called with a changed callback" do
      let(:callback) { proc{} }
      it { is_expected.to be true }
      include_context "for a running timer", seconds: 1
    end
  end

  describe "#cancel" do
    subject { instance.cancel }

    before { expect(instance).to receive(:trigger_event).with(:cancel, instance).and_call_original }
    it { is_expected.to be true }
    include_context "for a canceled timer"
  end

  describe "#trigger" do
    subject { instance.trigger }

    context "when canceled" do
      before { instance.cancel }
      it { is_expected.to raise_error AggregatedTimers::Error, 'timer canceled' }
    end

    context "when one-shot" do
      let(:repeat) { false }
      before { expect(callback).to receive(:call) }
      it { is_expected.to be true }
      include_context "for a canceled timer"
    end

    context "when recurring" do
      let(:repeat) { true }
      before { expect(callback).to receive(:call) }
      let!(:start_time) { instance.timeout_time }
      it { is_expected.to be true }
      include_context "for a running timer", seconds: 1.5, repeat: true
    end
  end

  describe "#inspect" do
    subject { instance.inspect }
    it { is_expected.to eq "#<#{described_class}:0x#{'%014x' % instance.__id__} waits another #{instance.waiting_time.round(3)} seconds>" }

    context "when canceled" do
      before { instance.cancel }
      it { is_expected.to eq "#<#{described_class}:0x#{'%014x' % instance.__id__} CANCELED>" }
    end
  end
end
