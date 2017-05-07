describe "using #wait in concurrent blocks" do
  subject(:loop) { IOEventLoop.new }

  describe "waiting for given seconds" do
    let(:seconds) { 0.01 }

    let(:wait_proc) { proc do
      loop.wait(seconds)
      Time.now.to_f
    end }

    let!(:start_time) { Time.now.to_f }

    context "when originating inside a concurrent block" do
      subject { loop.concurrently(&wait_proc).result }
      it { is_expected.to be_within(0.1*seconds).of(start_time+seconds) }
    end

    context "when originating outside a concurrent block" do
      subject { wait_proc.call }
      it { is_expected.to be_within(0.1*seconds).of(start_time+seconds) }
    end
  end

  describe "evaluating/cancelling the concurrent block while it is waiting" do
    subject { concurrency.result }

    let(:wait_time) { 0.0001 }
    let!(:concurrency) { loop.concurrently{ loop.wait wait_time; :completed } }

    before { loop.concurrently do
      # cancel the concurrent block half way through the waiting time
      loop.wait wait_time/2
      concurrency.evaluate_to :intercepted

      # Wait after the timer would have been triggered to make sure the
      # concurrent block is not resumed then (i.e. watching the timeout is
      # properly cancelled)
      loop.wait wait_time
    end.result }

    it { is_expected.to be :intercepted }
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
    let(:callback1) { proc{ :result1 } }
    let(:callback2) { proc{ :result2 } }
    let(:callback3) { proc{ :result3 } }

    context "when no block has been cancelled" do
      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).to receive(:call).ordered.and_call_original }
      before { expect(callback3).to receive(:call).ordered.and_call_original }

      it { is_expected.not_to raise_error }
      after { expect(concurrency1.result).to be :result1 }
      after { expect(concurrency2.result).to be :result2 }
      after { expect(concurrency3.result).to be :result3 }
    end

    context "when the first block has been cancelled" do
      before { concurrency1.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).to receive(:call).ordered.and_call_original }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect{ concurrency1.result }.to raise_error IOEventLoop::CancelledError }
      after { expect(concurrency2.result).to be :result2 }
      after { expect(concurrency3.result).to be :result3 }
    end

    context "when the first and second block have been cancelled" do
      before { concurrency1.cancel }
      before { concurrency2.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect{ concurrency1.result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrency2.result }.to raise_error IOEventLoop::CancelledError }
      after { expect(concurrency3.result).to be :result3 }
    end

    context "when all blocks have been cancelled" do
      before { concurrency1.cancel }
      before { concurrency2.cancel }
      before { concurrency3.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
      after { expect{ concurrency1.result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrency2.result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrency3.result }.to raise_error IOEventLoop::CancelledError }
    end

    context "when the second block has been cancelled" do
      before { concurrency2.cancel }

      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect(concurrency1.result).to be :result1 }
      after { expect{ concurrency2.result }.to raise_error IOEventLoop::CancelledError }
      after { expect(concurrency3.result).to be :result3 }
    end

    context "when the second and last block have been cancelled" do
      before { concurrency2.cancel }
      before { concurrency3.cancel }

      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
      after { expect(concurrency1.result).to be :result1 }
      after { expect{ concurrency2.result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrency3.result }.to raise_error IOEventLoop::CancelledError }
    end

    context "when all timers are triggered in one go" do
      let(:seconds1) { 0 }
      let(:seconds2) { 0 }
      let(:seconds3) { 0 }

      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).to receive(:call).ordered.and_call_original }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect(concurrency1.result).to be :result1 }
      after { expect(concurrency2.result).to be :result2 }
      after { expect(concurrency3.result).to be :result3 }
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