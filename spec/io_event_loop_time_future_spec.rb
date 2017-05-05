describe IOEventLoop::TimeFuture do
  subject(:instance) { IOEventLoop.new }

  describe "#await and #cancel" do
    subject { instance.start }

    let(:timer1) { instance.now_in(seconds1) }
    let(:timer2) { instance.now_in(seconds2) }
    let(:timer3) { instance.now_in(seconds3) }

    before { instance.concurrently{ (timer1.await; callback1.call) rescue nil } }
    before { instance.concurrently{ (timer2.await; callback2.call) rescue nil } }
    before { instance.concurrently{ (timer3.await; callback3.call) rescue nil } }
    let(:seconds1) { 0.0001 }
    let(:seconds2) { 0.0003 }
    let(:seconds3) { 0.0002 }
    let(:callback1) { proc{} }
    let(:callback2) { proc{} }
    let(:callback3) { proc{} }

    context "when no timer has been cancelled" do
      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback3).to receive(:call).ordered }
      before { expect(callback2).to receive(:call).ordered }

      it { is_expected.not_to raise_error }
    end

    context "when the first timer has been cancelled" do
      before { timer1.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered }
      before { expect(callback2).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end

    context "when the first and second timer have been cancelled" do
      before { timer1.cancel }
      before { timer3.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      before { expect(callback2).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end

    context "when all timers have been cancelled" do
      before { timer1.cancel }
      before { timer3.cancel }
      before { timer2.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      it { is_expected.not_to raise_error }
    end

    context "when the second timer has been cancelled" do
      before { timer3.cancel }

      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback3).not_to receive(:call) }
      before { expect(callback2).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end

    context "when the second and last timer have been cancelled" do
      before { timer3.cancel }
      before { timer2.cancel }

      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback3).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      it { is_expected.not_to raise_error }
    end

    context "when a timer cancels a timer coming afterwards in the same batch" do
      let(:seconds1) { 0 }
      let(:seconds2) { 0.0001 }
      let(:seconds3) { 0 }
      let(:callback1) { proc{ timer3.cancel } }

      before { expect(callback1).to receive(:call).and_call_original }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
    end

    context "when all timers are triggered in one go" do
      let(:seconds1) { 0 }
      let(:seconds2) { 0 }
      let(:seconds3) { 0 }

      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback2).to receive(:call).ordered }
      before { expect(callback3).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end
  end

  describe "repeated execution in a fixed interval" do
    subject { instance.start }

    before { @count = 0 }
    before { instance.concurrently do
      while (@count += 1) < 4
        instance.now_in(0.0001).await
        callback.call
      end
    end }
    let(:callback) { proc{} }

    before { expect(callback).to receive(:call).exactly(3).times }
    it { is_expected.not_to raise_error }
  end
end