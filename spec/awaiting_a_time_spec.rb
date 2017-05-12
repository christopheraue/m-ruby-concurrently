describe "using #wait in concurrent procs" do
  subject(:loop) { IOEventLoop.new }

  describe "waiting for given seconds" do
    let(:seconds) { 0.01 }

    let(:wait_proc) { proc do
      loop.wait(seconds)
      @end_time = Time.now.to_f
    end }

    let!(:start_time) { Time.now.to_f }

    context "when originating inside a concurrently block" do
      subject { @end_time }
      before { loop.concurrently(&wait_proc) }

      # We need a reference concurrent block whose result we can await to
      # ensure we wait long enough for the concurrently block to finish.
      before { loop.concurrent_proc(&wait_proc).await_result }

      it { is_expected.to be_within(0.1*seconds).of(start_time+seconds) }
    end

    context "when originating inside a concurrent proc" do
      subject { loop.concurrent_proc(&wait_proc).await_result }
      it { is_expected.to be_within(0.1*seconds).of(start_time+seconds) }
    end

    context "when originating outside a concurrent proc" do
      subject { wait_proc.call }
      it { is_expected.to be_within(0.1*seconds).of(start_time+seconds) }
    end
  end

  describe "evaluating/cancelling the concurrent proc while it is waiting" do
    subject { concurrent_proc.await_result }

    let(:wait_time) { 0.0001 }
    let!(:concurrent_proc) { loop.concurrent_proc{ loop.wait wait_time; :completed } }

    before { loop.concurrent_proc do
      # cancel the concurrent proc right away
      concurrent_proc.evaluate_to :intercepted

      # Wait after the timer would have been triggered to make sure the
      # concurrent proc is not resumed then (i.e. watching the timeout is
      # properly cancelled)
      loop.wait wait_time
    end.await_result }

    it { is_expected.to be :intercepted }
  end

  describe "order of multiple deferred concurrent_proc blocks" do
    subject { concurrent_proc.await_result }

    let!(:concurrent_proc1) { loop.concurrent_proc{ loop.wait(seconds1); callback1.call } }
    let!(:concurrent_proc2) { loop.concurrent_proc{ loop.wait(seconds2); callback2.call } }
    let!(:concurrent_proc3) { loop.concurrent_proc{ loop.wait(seconds3); callback3.call } }
    let(:concurrent_proc) { loop.concurrent_proc{ loop.wait(0.0004) } }
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
      after { expect(concurrent_proc1.await_result).to be :result1 }
      after { expect(concurrent_proc2.await_result).to be :result2 }
      after { expect(concurrent_proc3.await_result).to be :result3 }
    end

    context "when the first block has been cancelled" do
      before { concurrent_proc1.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).to receive(:call).ordered.and_call_original }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect{ concurrent_proc1.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect(concurrent_proc2.await_result).to be :result2 }
      after { expect(concurrent_proc3.await_result).to be :result3 }
    end

    context "when the first and second block have been cancelled" do
      before { concurrent_proc1.cancel }
      before { concurrent_proc2.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect{ concurrent_proc1.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrent_proc2.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect(concurrent_proc3.await_result).to be :result3 }
    end

    context "when all blocks have been cancelled" do
      before { concurrent_proc1.cancel }
      before { concurrent_proc2.cancel }
      before { concurrent_proc3.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
      after { expect{ concurrent_proc1.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrent_proc2.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrent_proc3.await_result }.to raise_error IOEventLoop::CancelledError }
    end

    context "when the second block has been cancelled" do
      before { concurrent_proc2.cancel }

      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect(concurrent_proc1.await_result).to be :result1 }
      after { expect{ concurrent_proc2.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect(concurrent_proc3.await_result).to be :result3 }
    end

    context "when the second and last block have been cancelled" do
      before { concurrent_proc2.cancel }
      before { concurrent_proc3.cancel }

      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
      after { expect(concurrent_proc1.await_result).to be :result1 }
      after { expect{ concurrent_proc2.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrent_proc3.await_result }.to raise_error IOEventLoop::CancelledError }
    end

    context "when all timers are triggered in one go" do
      let(:seconds1) { 0 }
      let(:seconds2) { 0 }
      let(:seconds3) { 0 }

      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).to receive(:call).ordered.and_call_original }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect(concurrent_proc1.await_result).to be :result1 }
      after { expect(concurrent_proc2.await_result).to be :result2 }
      after { expect(concurrent_proc3.await_result).to be :result3 }
    end
  end

  describe "repeated execution in a fixed interval" do
    subject { concurrent_proc.await_result }

    before { @count = 0 }
    let(:concurrent_proc) { loop.concurrent_proc do
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