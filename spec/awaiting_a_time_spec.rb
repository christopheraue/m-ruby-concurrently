describe "using #wait in concurrent procs" do
  subject(:loop) { IOEventLoop.new }

  describe "waiting for given seconds" do
    let(:seconds) { 0.01 }

    let(:wait_proc) { proc do
      loop.wait(seconds)
      Time.now.to_f
    end }

    let!(:start_time) { Time.now.to_f }

    context "when originating inside a concurrent proc" do
      subject { loop.concurrent_proc(&wait_proc).call }
      it { is_expected.to be_within(0.2*seconds).of(start_time+seconds) }
    end

    context "when originating outside a concurrent proc" do
      subject { wait_proc.call }
      it { is_expected.to be_within(0.2*seconds).of(start_time+seconds) }
    end
  end

  describe "evaluating/cancelling the concurrent evaluation while it is waiting" do
    subject { concurrent_evaluation.await_result }

    let(:wait_time) { 0.0001 }
    let!(:concurrent_evaluation) { loop.concurrent_proc{ loop.wait wait_time; :completed }.call_detached }

    before { loop.concurrent_proc do
      # cancel the concurrent evaluation right away
      concurrent_evaluation.conclude_with :intercepted

      # Wait after the timer would have been triggered to make sure the
      # concurrent evaluation is not resumed then (i.e. watching the timeout
      # is properly cancelled)
      loop.wait wait_time
    end.call }

    it { is_expected.to be :intercepted }
  end

  describe "order of multiple deferred concurrent evaluations" do
    subject { concurrent_evaluation.await_result }

    let!(:concurrent_evaluation1) { loop.concurrent_proc{ loop.wait(seconds1); callback1.call }.call_detached }
    let!(:concurrent_evaluation2) { loop.concurrent_proc{ loop.wait(seconds2); callback2.call }.call_detached }
    let!(:concurrent_evaluation3) { loop.concurrent_proc{ loop.wait(seconds3); callback3.call }.call_detached }
    let(:concurrent_evaluation) { loop.concurrent_proc{ loop.wait(0.0004) }.call_detached }
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
      after { expect(concurrent_evaluation1.await_result).to be :result1 }
      after { expect(concurrent_evaluation2.await_result).to be :result2 }
      after { expect(concurrent_evaluation3.await_result).to be :result3 }
    end

    context "when the first block has been cancelled" do
      before { concurrent_evaluation1.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).to receive(:call).ordered.and_call_original }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect{ concurrent_evaluation1.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect(concurrent_evaluation2.await_result).to be :result2 }
      after { expect(concurrent_evaluation3.await_result).to be :result3 }
    end

    context "when the first and second block have been cancelled" do
      before { concurrent_evaluation1.cancel }
      before { concurrent_evaluation2.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect{ concurrent_evaluation1.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrent_evaluation2.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect(concurrent_evaluation3.await_result).to be :result3 }
    end

    context "when all evaluations have been cancelled" do
      before { concurrent_evaluation1.cancel }
      before { concurrent_evaluation2.cancel }
      before { concurrent_evaluation3.cancel }

      before { expect(callback1).not_to receive(:call) }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
      after { expect{ concurrent_evaluation1.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrent_evaluation2.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrent_evaluation3.await_result }.to raise_error IOEventLoop::CancelledError }
    end

    context "when the second block has been cancelled" do
      before { concurrent_evaluation2.cancel }

      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect(concurrent_evaluation1.await_result).to be :result1 }
      after { expect{ concurrent_evaluation2.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect(concurrent_evaluation3.await_result).to be :result3 }
    end

    context "when the second and last block have been cancelled" do
      before { concurrent_evaluation2.cancel }
      before { concurrent_evaluation3.cancel }

      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).not_to receive(:call) }
      before { expect(callback3).not_to receive(:call) }
      it { is_expected.not_to raise_error }
      after { expect(concurrent_evaluation1.await_result).to be :result1 }
      after { expect{ concurrent_evaluation2.await_result }.to raise_error IOEventLoop::CancelledError }
      after { expect{ concurrent_evaluation3.await_result }.to raise_error IOEventLoop::CancelledError }
    end

    context "when all timers are triggered in one go" do
      let(:seconds1) { 0 }
      let(:seconds2) { 0 }
      let(:seconds3) { 0 }

      before { expect(callback1).to receive(:call).ordered.and_call_original }
      before { expect(callback2).to receive(:call).ordered.and_call_original }
      before { expect(callback3).to receive(:call).ordered.and_call_original }
      it { is_expected.not_to raise_error }
      after { expect(concurrent_evaluation1.await_result).to be :result1 }
      after { expect(concurrent_evaluation2.await_result).to be :result2 }
      after { expect(concurrent_evaluation3.await_result).to be :result3 }
    end
  end

  describe "repeated execution in a fixed interval" do
    subject { concurrent_evaluation.await_result }

    before { @count = 0 }
    let(:concurrent_evaluation) { loop.concurrent_proc do
      while (@count += 1) < 4
        loop.wait(0.0001)
        callback.call
      end
      :result
    end.call_detached }
    let(:callback) { proc{} }

    before { expect(callback).to receive(:call).exactly(3).times }
    it { is_expected.to be :result }
  end
end