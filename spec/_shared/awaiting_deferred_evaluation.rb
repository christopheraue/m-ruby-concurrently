shared_examples_for "awaiting the result of a deferred evaluation" do
  let(:loop) { IOEventLoop.new }
  let(:concurrent_evaluation) { loop.concurrent_proc(&wait_proc).call_detached }

  let(:wait_options) { {} }
  let(:evaluation_time) { 0.001 }
  let(:result) { :result }

  shared_examples_for "waiting with a timeout" do
    context "when limiting the wait time" do
      let(:wait_options) { { within: timeout_time, timeout_result: timeout_result } }
      let(:timeout_result) { :timeout_result }

      context "when the result arrives in time" do
        let(:timeout_time) { 2*evaluation_time }
        it { is_expected.to eq result }
      end

      context "when evaluation of result is too slow" do
        let(:timeout_time) { 0.5*evaluation_time }

        context "when no timeout result is given" do
          before { wait_options.delete :timeout_result }
          it { is_expected.to raise_error IOEventLoop::TimeoutError, "evaluation timed out after #{wait_options[:within]} second(s)" }
        end

        context "when a timeout result is given" do
          let(:timeout_result) { :timeout_result }
          it { is_expected.to be :timeout_result }
        end
      end
    end
  end

  context "when originating inside a concurrent proc" do
    subject { concurrent_evaluation.await_result }
    it { is_expected.to eq result }

    include_examples "waiting with a timeout"
  end

  context "when originating outside a concurrent proc" do
    subject { wait_proc.call }
    it { is_expected.to eq result }

    include_examples "waiting with a timeout"
  end

  describe "evaluating the concurrent evaluation while it is waiting" do
    subject { concurrent_evaluation.await_result }

    before do # make sure the concurrent evaluation is started before evaluating it
      concurrent_evaluation
    end

    before { loop.concurrent_proc do
      # cancel the concurrent evaluation right away
      concurrent_evaluation.conclude_with :intercepted

      # Wait after the event is triggered to make sure the concurrent evaluation
      # is not resumed then (i.e. watching the event is properly cancelled)
      loop.wait evaluation_time
    end.call }

    it { is_expected.to be :intercepted }
  end
end