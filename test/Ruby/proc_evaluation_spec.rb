describe Concurrently::Proc::Evaluation do
  describe "attached data" do
    let(:evaluation) { concurrent_proc{ :result }.call_detached }
    before { evaluation[:key] = :value }
    it { expect(evaluation[:key]).to be :value }
    it { expect(evaluation.key? :key).to be true }
    it { expect(evaluation.keys).to eq [:key] }
  end

  describe "#await_result" do
    subject { evaluation.await_result(&with_result) }

    let(:conproc) { concurrent_proc(&wait_proc) }
    let(:evaluation) { conproc.call_nonblock }
    let(:with_result) { nil }
    let(:result) { :result }

    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:inner_evaluation) { concurrent_proc{ await_resume! }.call_nonblock }
      let(:wait_proc) { proc{ inner_evaluation.await_result wait_options } }

      def resume
        inner_evaluation.resume! result
      end
    end

    context "when it evaluates to a result" do
      let(:wait_proc) { proc{ wait 0.0001; result } }

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
      let(:wait_proc) { proc{ wait 0.0001; raise 'error' } }

      before { expect(evaluation).not_to be_concluded }
      after { expect(evaluation).to be_concluded }

      before { expect(STDERR).to receive(:puts).with(
        be_a(RuntimeError).and have_attributes message: "error") }
      before { expect(conproc).to receive(:trigger).with(:error, (be_a(RuntimeError).
        and have_attributes message: "error")) }
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
      let!(:evaluation) { concurrent_proc{ wait(0.005); :result }.call_nonblock }
      let!(:evaluation1) { concurrent_proc{ evaluation.await_result }.call_nonblock }
      let!(:evaluation2) { concurrent_proc{ evaluation.await_result within: 0, timeout_result: :timeout_result }.call_nonblock }

      it { is_expected.to be :result }
      after { expect(evaluation1.await_result).to be :result }
      after { expect(evaluation2.await_result).to be :timeout_result }
    end
  end

  describe "#conclude_to" do
    before { expect(evaluation).not_to be_concluded }
    after { expect(evaluation).to be_concluded }

    context "when doing it before requesting the result" do
      subject { evaluation.conclude_to result }

      let(:evaluation) { concurrent_proc{ :result }.call_detached }

      context "when concluding to an error" do
        let(:result) { RuntimeError.new 'error message' }
        it { is_expected.to be :concluded }
        after { expect{ evaluation.await_result }.to raise_error 'error message' }
      end

      context "when concluding to a result" do
        let(:result) { :result }
        it { is_expected.to be :concluded }
        after { expect{ evaluation.await_result }.to be :result}
      end
    end

    context "when doing it after requesting the result" do
      subject { concurrent_proc{ evaluation.conclude_to result }.call }

      let(:evaluation) { concurrent_proc{ wait(0.0001) }.call_nonblock }

      context "when concluding to an error" do
        let(:result) { RuntimeError.new 'error message' }
        it { is_expected.to be :concluded }
        after { expect{ evaluation.await_result }.to raise_error 'error message' }
      end

      context "when concluding to a result" do
        let(:result) { :result }
        it { is_expected.to be :concluded }
        after { expect{ evaluation.await_result }.to be :result}
      end
    end

    context "when concluding after it is already evaluated" do
      subject { evaluation.conclude_to :result }

      let(:evaluation) { concurrent_proc{ :result }.call_detached }
      before { evaluation.await_result }

      it { is_expected.to raise_error Concurrently::Evaluation::Error, "already concluded" }
    end

    context "when concluding an evaluation from a nested proc" do
      subject { evaluation.await_result }

      let!(:evaluation) { concurrent_proc do
        concurrent_proc do
          concurrent_proc do
            evaluation.conclude_to :concluded
          end.call_detached

          # The return value of this concurrent proc would be used as a
          # proc in the fiber of the outer concurrent proc unless it is
          # not properly concluded.
          :trouble_maker
        end.call_detached.await_result
      end.call_detached }

      it { is_expected.not_to raise_error }
    end
  end

  describe "#resume!" do
    subject { evaluation.await_result }
    let!(:evaluation) { concurrent_proc{ await_resume! }.call_nonblock }

    it_behaves_like "#resume!"
  end
end