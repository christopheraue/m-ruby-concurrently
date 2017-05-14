describe "using #await_event in concurrent procs" do
  let(:loop) { IOEventLoop.new }
  let(:concurrent_evaluation) { loop.concurrent_proc(&wait_proc).call }
  let(:wait_proc) { proc{ @result = loop.await_event object, :event } }

  let(:object) { Object.new.extend CallbacksAttachable }
  let(:waiting_time) { 0.001 }

  before { loop.concurrent_proc do
    loop.wait waiting_time
    object.trigger :event, :result
  end.call }

  context "when originating inside a concurrently block" do
    subject { @result }
    before { loop.concurrently(&wait_proc) }

    # We need a reference concurrent block whose result we can await to
    # ensure we wait long enough for the concurrently block to finish.
    before { loop.concurrent_proc{ loop.wait waiting_time }.call.await_result }

    it { is_expected.to be :result }
  end

  context "when originating inside a concurrent proc" do
    subject { concurrent_evaluation.await_result }
    it { is_expected.to be :result }
  end

  context "when originating outside a concurrent proc" do
    subject { wait_proc.call }
    it { is_expected.to be :result }
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
      loop.wait waiting_time
    end.call.await_result }

    it { is_expected.to be :intercepted }
  end
end