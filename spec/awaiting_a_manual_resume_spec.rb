describe "using #await_manual_resume! in concurrent procs" do
  let(:loop) { IOEventLoop.new }
  let(:concurrent_evaluation) { loop.concurrent_proc(&wait_proc).call_detached }
  let(:wait_proc) { proc do
    @spec_fiber = Fiber.current
    loop.await_manual_resume!
  end }

  let(:waiting_time) { 0.001 }

  before { loop.concurrent_proc do
    loop.wait waiting_time
    loop.manually_resume! @spec_fiber, :result
  end.call_detached }

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
    end.call }

    it { is_expected.to be :intercepted }
  end
end