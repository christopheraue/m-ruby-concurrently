describe "using #await_event in concurrent futures" do
  let(:loop) { IOEventLoop.new }
  let(:concurrent_future) { loop.concurrent_future(&wait_proc) }
  let(:wait_proc) { proc{ @result = loop.await_event object, :event } }

  let(:object) { Object.new.extend CallbacksAttachable }
  let(:waiting_time) { 0.001 }

  before { loop.concurrent_future do
    loop.wait waiting_time
    object.trigger :event, :result
  end }

  context "when originating inside a concurrently block" do
    subject { @result }
    before { loop.concurrently(&wait_proc) }

    # We need a reference concurrent block whose result we can await to
    # ensure we wait long enough for the concurrently block to finish.
    before { loop.concurrent_future{ loop.wait waiting_time }.await_result }

    it { is_expected.to be :result }
  end

  context "when originating inside a concurrent future" do
    subject { concurrent_future.await_result }
    it { is_expected.to be :result }
  end

  context "when originating outside a concurrent future" do
    subject { wait_proc.call }
    it { is_expected.to be :result }
  end

  describe "evaluating the concurrent future while it is waiting" do
    subject { concurrent_future.await_result }

    before do # make sure the concurrent future is started before evaluating it
      concurrent_future
    end

    before { loop.concurrent_future do
      # cancel the concurrent future  right away
      concurrent_future.evaluate_to :intercepted

      # Wait after the event is triggered to make sure the concurrent future
      # is not resumed then (i.e. watching the event is properly cancelled)
      loop.wait waiting_time
    end.await_result }

    it { is_expected.to be :intercepted }
  end
end