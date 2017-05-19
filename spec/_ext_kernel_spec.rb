describe Kernel do
  before { Concurrently::EventLoop.current.reinitialize! }

  describe "#concurrently" do
    def call(*args, &block)
      concurrently(*args, &block)
    end

    it_behaves_like "EventLoop#concurrently"
  end

  describe "#concurrent_proc" do
    def call(*args, &block)
      concurrent_proc(*args, &block)
    end

    it_behaves_like "EventLoop#concurrent_proc"
  end

  describe "#wait" do
    def call(seconds)
      wait(seconds)
    end

    it_behaves_like "EventLoop#wait"

    describe "order of multiple deferred concurrent evaluations" do
      subject { evaluation.await_result }

      let!(:evaluation1) { concurrent_proc{ wait(seconds1); callback1.call }.call_detached }
      let!(:evaluation2) { concurrent_proc{ wait(seconds2); callback2.call }.call_detached }
      let!(:evaluation3) { concurrent_proc{ wait(seconds3); callback3.call }.call_detached }
      let(:evaluation) { concurrent_proc{ wait(0.0004) }.call_detached }
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
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect(evaluation2.await_result).to be :result2 }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when the first block has been cancelled" do
        before { evaluation1.cancel }

        before { expect(callback1).not_to receive(:call) }
        before { expect(callback2).to receive(:call).ordered.and_call_original }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect{ evaluation1.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect(evaluation2.await_result).to be :result2 }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when the first and second block have been cancelled" do
        before { evaluation1.cancel }
        before { evaluation2.cancel }

        before { expect(callback1).not_to receive(:call) }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect{ evaluation1.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect{ evaluation2.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when all evaluations have been cancelled" do
        before { evaluation1.cancel }
        before { evaluation2.cancel }
        before { evaluation3.cancel }

        before { expect(callback1).not_to receive(:call) }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).not_to receive(:call) }
        it { is_expected.not_to raise_error }
        after { expect{ evaluation1.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect{ evaluation2.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect{ evaluation3.await_result }.to raise_error Concurrently::Proc::CancelledError }
      end

      context "when the second block has been cancelled" do
        before { evaluation2.cancel }

        before { expect(callback1).to receive(:call).ordered.and_call_original }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect{ evaluation2.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when the second and last block have been cancelled" do
        before { evaluation2.cancel }
        before { evaluation3.cancel }

        before { expect(callback1).to receive(:call).ordered.and_call_original }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).not_to receive(:call) }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect{ evaluation2.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect{ evaluation3.await_result }.to raise_error Concurrently::Proc::CancelledError }
      end

      context "when all timers are triggered in one go" do
        let(:seconds1) { 0 }
        let(:seconds2) { 0 }
        let(:seconds3) { 0 }

        before { expect(callback1).to receive(:call).ordered.and_call_original }
        before { expect(callback2).to receive(:call).ordered.and_call_original }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect(evaluation2.await_result).to be :result2 }
        after { expect(evaluation3.await_result).to be :result3 }
      end
    end

    describe "repeated execution in a fixed interval" do
      subject { evaluation.await_result }

      before { @count = 0 }
      let(:evaluation) { concurrent_proc do
        while (@count += 1) < 4
          wait(0.0001)
          callback.call
        end
        :result
      end.call_detached }
      let(:callback) { proc{} }

      before { expect(callback).to receive(:call).exactly(3).times }
      it { is_expected.to be :result }
    end

    describe "the execution order of concurrent procs scheduled to run during a single iteration" do
      subject { wait 0; @counter += 1 }

      before { @counter = 0 }
      let!(:evaluation1) { concurrent_proc{ wait 0.0001; @counter += 1 }.call_nonblock }
      let!(:evaluation2) { concurrent_proc{ wait 0; @counter += 1 }.call_nonblock }
      let!(:evaluation3) { concurrent_proc{ @counter += 1 }.call_detached }
      # let the system clock progress so the block waiting non-zero seconds becomes pending
      before { sleep 0.0001 }

      it { is_expected.to be 4 }

      # scheduled starts come first, then the waiting procs
      after { expect(evaluation1.await_result).to be 3 }
      after { expect(evaluation2.await_result).to be 2 }
      after { expect(evaluation3.await_result).to be 1 }
    end
  end

  describe "#await_manual_resume!" do
    def call(options)
      await_manual_resume! options
    end

    it_behaves_like "EventLoop#await_manual_resume!"
  end
end