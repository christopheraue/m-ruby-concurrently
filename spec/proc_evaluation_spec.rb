describe Concurrently::Proc::Evaluation do
  before { Concurrently::EventLoop.current.reinitialize! }

  describe "#await_result" do
    subject { evaluation.await_result(&with_result) }

    let(:evaluation) { concurrent_proc(&wait_proc).call_detached }
    let(:with_result) { nil }
    let(:result) { :result }

    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:wait_proc) { proc do
        concurrent_proc{ wait evaluation_time; result }.call_detached.await_result wait_options
      end }
    end

    context "when it evaluates to a result" do
      let(:wait_proc) { proc{ result } }

      before { expect(evaluation).not_to be_concluded }
      after { expect(evaluation).to be_concluded }

      it { is_expected.to be :result }

      context "when requesting the result a second time" do
        before { evaluation.await_result }
        it { is_expected.to be :result }
      end

      context "when the result is an array" do
        let(:result) { %i(a b c) }
        it { is_expected.to eq %i(a b c) }
      end

      context "when a block to do something with the result is given" do
        context "when transforming to a non-error value" do
          let(:with_result) { proc{ |result| "transformed #{result} to result" } }
          it { is_expected.to eq "transformed result to result" }
        end

        context "when transforming to an error value" do
          let(:with_result) { proc{ |result| RuntimeError.new("transformed #{result} to error") } }
          it { is_expected.to raise_error RuntimeError, 'transformed result to error' }
        end
      end
    end

    context "when it evaluates to an error" do
      let(:wait_proc) { proc{ raise 'error' } }

      before { expect(evaluation).not_to be_concluded }
      after { expect(evaluation).to be_concluded }

      it { is_expected.to raise_error RuntimeError, 'error' }

      context "when requesting the result a second time" do
        before { evaluation.await_result rescue nil }
        it { is_expected.to raise_error RuntimeError, 'error' }
      end

      context "when a block to do something with the result is given" do
        context "when transforming to a non-error value" do
          let(:with_result) { proc{ |result| "transformed #{result} to result" } }
          it { is_expected.to eq "transformed error to result" }
        end

        context "when transforming to an error value" do
          let(:with_result) { proc{ |result| RuntimeError.new("transformed #{result} to error") } }
          it { is_expected.to raise_error RuntimeError, 'transformed error to error' }
        end
      end
    end

    context "when getting the result of a concurrent proc from two other ones" do
      let!(:evaluation) { concurrent_proc{ wait(0.0001); :result }.call_detached }
      let!(:evaluation1) { concurrent_proc{ evaluation.await_result }.call_detached }
      let!(:evaluation2) { concurrent_proc{ evaluation.await_result within: 0.00005, timeout_result: :timeout_result }.call_detached }

      it { is_expected.to be :result }
      after { expect(evaluation1.await_result).to be :result }
      after { expect(evaluation2.await_result).to be :timeout_result }
    end
  end

  describe "#cancel" do
    before { expect(evaluation).not_to be_concluded }
    after { expect(evaluation).to be_concluded }

    context "when doing it before requesting the result" do
      subject { evaluation.cancel *reason }

      let(:evaluation) { concurrent_proc{ :result }.call_detached }

      context "when giving no explicit reason" do
        let(:reason) { nil }
        it { is_expected.to be :cancelled }
        after { expect{ evaluation.await_result }.to raise_error Concurrently::Proc::CancelledError, "evaluation cancelled" }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }
        it { is_expected.to be :cancelled }
        after { expect{ evaluation.await_result }.to raise_error Concurrently::Proc::CancelledError, "cancel reason" }
      end
    end

    context "when doing it after requesting the result" do
      subject { concurrent_proc{ evaluation.cancel *reason }.call }

      let(:evaluation) { concurrent_proc{ wait(0.0001) }.call_detached }

      context "when giving no explicit reason" do
        let(:reason) { nil }
        it { is_expected.to be :cancelled }
        after { expect{ evaluation.await_result }.to raise_error Concurrently::Proc::CancelledError, "evaluation cancelled" }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }
        it { is_expected.to be :cancelled }
        after { expect{ evaluation.await_result }.to raise_error Concurrently::Proc::CancelledError, "cancel reason" }
      end
    end

    context "when cancelling after it is already evaluated" do
      subject { evaluation.cancel }

      let(:evaluation) { concurrent_proc{ :result }.call_detached }
      before { evaluation.await_result }

      it { is_expected.to raise_error Concurrently::Proc::Error, "already concluded" }
    end

    context "when concluding an evaluation from a nested proc" do
      subject { evaluation.await_result }

      let!(:evaluation) { concurrent_proc do
        concurrent_proc do
          concurrent_proc do
            evaluation.conclude_with :cancelled
          end.call_detached

          # The return value of this concurrent proc would be used as a
          # proc in the fiber of the outer concurrent proc unless it is
          # not properly cancelled.
          :trouble_maker
        end.call_detached.await_result
      end.call_detached }

      it { is_expected.not_to raise_error }
    end
  end

  describe "#manually_resume!" do
    subject { evaluation.await_result }
    def call(*args)
      evaluation.manually_resume! *args
    end
    let!(:evaluation) { concurrent_proc{ await_manual_resume! }.call_detached }

    it_behaves_like "#manually_resume!"
  end
end