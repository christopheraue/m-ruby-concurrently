describe "using #await_event in concurrent blocks" do
  let(:loop) { IOEventLoop.new }
  let(:concurrency) { loop.concurrently(&wait_proc) }
  let(:wait_proc) { proc{ loop.await_event object, :event } }

  let(:object) { Object.new.extend CallbacksAttachable }
  let(:waiting_time) { 0.001 }

  before { loop.concurrently do
    loop.wait waiting_time
    object.trigger :event, :result
  end }

  context "when originating inside a concurrent block" do
    subject { concurrency.result }
    it { is_expected.to be :result }
  end

  context "when originating outside a concurrent block" do
    subject { wait_proc.call }
    it { is_expected.to be :result }
  end

  describe "evaluating the concurrent block while it is waiting" do
    subject { concurrency.result }

    before do # make sure the concurrent block is started before evaluating it
      concurrency
    end

    before { loop.concurrently do
      # cancel the concurrent block half way through the waiting time
      loop.wait waiting_time/2
      concurrency.evaluate_to :intercepted

      # Wait after the event is triggered to make sure the concurrent block
      # is not resumed then (i.e. watching the event is properly cancelled)
      loop.wait waiting_time
    end.result }

    it { is_expected.to be :intercepted }
  end
end