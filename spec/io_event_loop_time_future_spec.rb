describe IOEventLoop::TimeFuture do
  subject(:loop) { IOEventLoop.new }
  
  describe "using #wait in concurrent blocks" do
    subject { concurrency.result }

    let(:seconds) { 0.01 }
    let(:concurrency) { loop.concurrently do
      loop.wait(seconds)
      Time.now.to_f
    end }
    let!(:start_time) { Time.now.to_f }

    it { is_expected.to be_within(0.1*seconds).of(start_time+seconds) }
  end

  describe "#cancel" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently{ future.await } }
    let(:future) { loop.now_in(0.0002) }

    context "when doing it before awaiting it" do
      before { future.cancel }
      it { is_expected.to raise_error IOEventLoop::CancelledError, "waiting cancelled" }
    end

    context "when doing it after awaiting it" do
      before { loop.concurrently do
        loop.wait(0.0001)
        future.cancel
      end }

      it { is_expected.to raise_error IOEventLoop::CancelledError, "waiting cancelled" }
    end
  end

  describe "order of multiple deferred concurrently blocks" do
    subject { concurrency.result }

    let!(:timer1) { loop.now_in(seconds1) }
    let!(:timer2) { loop.now_in(seconds2) }
    let!(:timer3) { loop.now_in(seconds3) }

    let!(:concurrency1) { loop.concurrently{ (timer1.await; callback1.call) rescue nil } }
    let!(:concurrency2) { loop.concurrently{ (timer2.await; callback2.call) rescue nil } }
    let!(:concurrency3) { loop.concurrently{ (timer3.await; callback3.call) rescue nil } }
    let(:concurrency) { loop.concurrently{ loop.wait(0.0004) } }
    let(:seconds1) { 0.0001 }
    let(:seconds2) { 0.0002 }
    let(:seconds3) { 0.0003 }
    let(:callback1) { proc{} }
    let(:callback2) { proc{} }
    let(:callback3) { proc{} }

    context "when no timer has been cancelled" do
      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback2).to receive(:call).ordered }
      before { expect(callback3).to receive(:call).ordered }

      it { is_expected.not_to raise_error }
    end

    context "when the first timer has been cancelled" do
      before { timer1.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).to receive(:call).ordered }
      before { expect(callback3).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end

    context "when the first and second timer have been cancelled" do
      before { timer1.cancel }
      before { timer2.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end

    context "when all timers have been cancelled" do
      before { timer1.cancel }
      before { timer2.cancel }
      before { timer3.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
    end

    context "when the second timer has been cancelled" do
      before { timer2.cancel }

      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered }
      it { is_expected.not_to raise_error }
    end

    context "when the second and last timer have been cancelled" do
      before { timer2.cancel }
      before { timer3.cancel }

      before { expect(callback1).to receive(:call).ordered }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
    end

    context "when a timer cancels a timer coming afterwards in the same batch" do
      let(:seconds1) { 0 }
      let(:seconds2) { 0.0001 }
      let(:seconds3) { 0 }
      let(:callback1) { proc{ timer3.cancel } }

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