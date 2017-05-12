describe "using #await_event in concurrent procs" do
  let(:loop) { IOEventLoop.new }
  let(:concurrent_proc) { loop.concurrent_proc(&wait_proc) }
  let(:wait_proc) { proc{ loop.await_event object, :event } }

  let(:object) { Object.new.extend CallbacksAttachable }
  let(:waiting_time) { 0.001 }

  before { loop.concurrent_proc do
    loop.wait waiting_time
    object.trigger :event, :result
  end }

  context "when originating inside a concurrent proc" do
    subject { concurrent_proc.await_result }
    it { is_expected.to be :result }
  end

  context "when originating outside a concurrent proc" do
    subject { wait_proc.call }
    it { is_expected.to be :result }
  end

  describe "evaluating the concurrent proc while it is waiting" do
    subject { concurrent_proc.await_result }

    before do # make sure the concurrent proc is started before evaluating it
      concurrent_proc
    end

    before { loop.concurrent_proc do
      # cancel the concurrent proc  right away
      concurrent_proc.evaluate_to :intercepted

      # Wait after the event is triggered to make sure the concurrent proc
      # is not resumed then (i.e. watching the event is properly cancelled)
      loop.wait waiting_time
    end.await_result }

    it { is_expected.to be :intercepted }
  end
end