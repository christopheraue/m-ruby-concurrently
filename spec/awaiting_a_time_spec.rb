describe "using #wait in concurrent blocks" do
  subject(:loop) { IOEventLoop.new }

  describe "the simplest case" do
    subject { concurrency.result }

    let(:seconds) { 0.01 }
    let(:concurrency) { loop.concurrently do
      loop.wait(seconds)
      Time.now.to_f
    end }
    let!(:start_time) { Time.now.to_f }

    it { is_expected.to be_within(0.1*seconds).of(start_time+seconds) }
  end

  describe "order of multiple deferred concurrently blocks" do
    subject { concurrency.result }

    let!(:concurrency1) { loop.concurrently{ loop.wait(seconds1); callback1.call } }
    let!(:concurrency2) { loop.concurrently{ loop.wait(seconds2); callback2.call } }
    let!(:concurrency3) { loop.concurrently{ loop.wait(seconds3); callback3.call } }
    let(:concurrency) { loop.concurrently{ loop.wait(0.0004) } }
    let(:seconds1) { 0.0001 }
    let(:seconds2) { 0.0002 }
    let(:seconds3) { 0.0003 }
    let(:callback1) { proc{} }
    let(:callback2) { proc{} }
    let(:callback3) { proc{} }

    context "when no block has been cancelled" do
      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback2).to receive(:call).ordered }
      before { expect(callback3).to receive(:call).ordered }

      it { is_expected.not_to raise_error }
    end

    context "when the first block has been cancelled" do
      before { concurrency1.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).to receive(:call).ordered }
      before { expect(callback3).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end

    context "when the first and second block have been cancelled" do
      before { concurrency1.cancel }
      before { concurrency2.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end

    context "when all timers have been cancelled" do
      before { concurrency1.cancel }
      before { concurrency2.cancel }
      before { concurrency3.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
    end

    context "when the second block has been cancelled" do
      before { concurrency2.cancel }

      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end

    context "when the second and last block have been cancelled" do
      before { concurrency2.cancel }
      before { concurrency3.cancel }

      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
    end

    context "when all timers are triggered in one go" do
      let(:seconds1) { 0 }
      let(:seconds2) { 0 }
      let(:seconds3) { 0 }

      before { expect(callback3).to receive(:call).ordered }
      before { expect(callback2).to receive(:call).ordered }
      before { expect(callback1).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end
  end

  describe "repeated execution in a fixed interval" do
    subject { concurrency.result }

    before { @count = 0 }
    let(:concurrency) { loop.concurrently do
      while (@count += 1) < 4
        loop.wait(0.0001)
        callback.call
      end
      :result
    end }
    let(:callback) { proc{} }

    before { expect(callback).to receive(:call).exactly(3).times }
    it { is_expected.to be :result }
  end
end