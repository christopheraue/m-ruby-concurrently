describe Kernel do
  describe "#concurrently" do
    def call(*args, &block)
      concurrently(*args, &block)
    end

    it_behaves_like "#concurrently"
  end

  describe "#concurrent_proc" do
    context "when it configures no custom evaluation" do
      subject { concurrent_proc{ wait 0.01 } }
      it { is_expected.to be_a(Concurrently::Proc).and have_attributes(call_nonblock: be_a(Concurrently::Proc::Evaluation)) }
    end

    context "when it configures a custom evaluation" do
      subject { concurrent_proc(custom_evaluation_class){ wait 0.01 } }
      let(:custom_evaluation_class) { Class.new(Concurrently::Proc::Evaluation) }
      it { is_expected.to be_a(Concurrently::Proc).and have_attributes(call_nonblock: be_a(custom_evaluation_class)) }
    end
  end

  describe "#wait" do
    describe "waiting for given seconds" do
      subject { @end_time - @start_time }

      let(:seconds) { 0.02 }

      let(:wait_proc) { proc do
        @start_time = Time.now.to_f
        @wait_result = wait seconds
        @end_time = Time.now.to_f
      end }

      after { expect(@wait_result).to be true }

      context "when originating inside a concurrent proc" do
        before { concurrent_proc(&wait_proc).call }
        it { is_expected.to be_within(0.1*seconds).of(seconds) }
      end

      context "when originating outside a concurrent proc" do
        before { wait_proc.call }
        it { is_expected.to be_within(0.1*seconds).of(seconds) }
      end
    end

    describe "evaluating/cancelling the concurrent evaluation while it is waiting" do
      subject { evaluation.await_result }

      let(:wait_time) { 0.0001 }
      let!(:evaluation) { concurrent_proc{ wait wait_time; :completed }.call_nonblock }

      before { concurrent_proc do
        # cancel the concurrent evaluation right away
        evaluation.conclude_to :intercepted

        # Wait after the timer would have been triggered to make sure the
        # concurrent evaluation is not resumed then (i.e. watching the timeout
        # is properly cancelled)
        wait wait_time
      end.call }

      it { is_expected.to be :intercepted }
    end

    describe "order of multiple deferred concurrent evaluations" do
      subject { evaluation.await_result }

      let!(:evaluation1) { concurrent_proc{ wait(seconds1); callback1.call }.call_nonblock }
      let!(:evaluation2) { concurrent_proc{ wait(seconds2); callback2.call }.call_nonblock }
      let!(:evaluation3) { concurrent_proc{ wait(seconds3); callback3.call }.call_nonblock }
      let(:evaluation) { concurrent_proc{ wait(0.0004) }.call_nonblock }
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
        before { evaluation1.conclude_to nil }

        before { expect(callback1).not_to receive(:call) }
        before { expect(callback2).to receive(:call).ordered.and_call_original }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be nil }
        after { expect(evaluation2.await_result).to be :result2 }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when the first and second block have been cancelled" do
        before { evaluation1.conclude_to nil }
        before { evaluation2.conclude_to nil }

        before { expect(callback1).not_to receive(:call) }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be nil }
        after { expect(evaluation2.await_result).to be nil }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when all evaluations have been cancelled" do
        before { evaluation1.conclude_to nil }
        before { evaluation2.conclude_to nil }
        before { evaluation3.conclude_to nil }

        before { expect(callback1).not_to receive(:call) }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).not_to receive(:call) }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be nil }
        after { expect(evaluation2.await_result).to be nil }
        after { expect(evaluation3.await_result).to be nil }
      end

      context "when the second block has been cancelled" do
        before { evaluation2.conclude_to nil }

        before { expect(callback1).to receive(:call).ordered.and_call_original }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect(evaluation2.await_result).to be nil }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when the second and last block have been cancelled" do
        before { evaluation2.conclude_to nil }
        before { evaluation3.conclude_to nil }

        before { expect(callback1).to receive(:call).ordered.and_call_original }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).not_to receive(:call) }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect(evaluation2.await_result).to be nil }
        after { expect(evaluation3.await_result).to be nil }
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
      end.call_nonblock }
      let(:callback) { proc{} }

      before { expect(callback).to receive(:call).exactly(3).times }
      it { is_expected.to be :result }
    end

    describe "the execution order of concurrent procs scheduled to run during a single iteration" do
      subject { wait 0; @counter += 1 }

      before { @counter = 0 }
      let!(:evaluation1) { concurrent_proc{ wait 0.01; @counter += 1 }.call_nonblock }
      let!(:evaluation2) { concurrent_proc{ wait 0; @counter += 1 }.call_nonblock }
      let!(:evaluation3) { concurrent_proc{ @counter += 1 }.call_detached }
      # let the system clock progress so the block waiting non-zero seconds becomes pending
      before { sleep 0.01 }

      it { is_expected.to be 4 }

      # scheduled starts come first, then the waiting procs
      after { expect(evaluation1.await_result).to be 3 }
      after { expect(evaluation2.await_result).to be 2 }
      after { expect(evaluation3.await_result).to be 1 }
    end
  end

  describe "#await_resume!" do
    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:wait_proc) { proc{ await_resume! wait_options } }

      def resume
        evaluation.resume! result
      end
    end
  end

  describe "#await_fastest" do
    it_behaves_like "awaiting the result of a deferred evaluation" do
      let!(:evaluation0) { concurrent_proc{ await_resume! }.call_nonblock }
      let!(:evaluation1) { concurrent_proc{ await_resume! }.call_nonblock }
      let(:wait_proc) { proc{ await_fastest evaluation0, evaluation1, wait_options } }
      let(:result) { evaluation1 }

      # check concluding the other evaluation does not cause trouble
      after { evaluation0.resume! }

      def resume
        evaluation1.resume!
      end

      context "when one of the evaluations is already concluded" do
        subject { wait_proc.call }
        before { evaluation1.resume! }
        it { is_expected.to be evaluation1 }
      end
    end
  end
end