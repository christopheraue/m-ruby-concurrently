shared_examples_for "#concurrently" do
  context "when called with arguments" do
    subject { @result }

    before { call(:arg1, :arg2) do |*args|
      @result = args
      @spec_evaluation.resume!
    end }

    # We need a reference wait to ensure we wait long enough for the
    # evaluation to finish.
    before do
      @spec_evaluation = Concurrently::Evaluation.current
      await_resume!
    end

    it { is_expected.to eq [:arg1, :arg2] }
  end

  context "when starting/resuming the fiber raises an error" do
    subject { call{}; wait 0 }
    let(:fiber_pool) { Concurrently::EventLoop::ProcFiberPool.new(Concurrently::EventLoop.current) }
    let!(:fiber) { Concurrently::Proc::Fiber.new(fiber_pool) }
    before { allow(fiber).to receive(:resume).and_raise(FiberError, 'resume error') }
    before { fiber_pool.return fiber }
    before { allow(Concurrently::EventLoop.current).to receive(:proc_fiber_pool).and_return(fiber_pool) }

    it { is_expected.to raise_error FiberError, 'resume error' }
  end

  context "when the code inside the block raises a recoverable error" do
    subject { call{ raise StandardError, 'error' }; wait 0 }

    before { expect_any_instance_of(Concurrently::Proc).to receive(:trigger).with(:error,
      (be_a(StandardError).and have_attributes message: 'error')) }
    it { is_expected.not_to raise_error }
  end

  context "when the code inside the block raises an error tearing down the event loop" do
    subject { call{ raise Exception, 'error' }; wait 0 }
    it { is_expected.to raise_error Exception, 'error' }
  end

  describe "the reuse of proc fibers" do
    subject { @fiber2 }

    let!(:evaluation1) { concurrent_proc{ @fiber1 = Fiber.current }.call }
    let!(:evaluation2) { call do
      @fiber2 = Fiber.current
      @spec_evaluation.resume!
    end }

    # We need a reference wait to ensure we wait long enough for the
    # evaluation to finish.
    before do
      @spec_evaluation = Concurrently::Evaluation.current
      await_resume!
    end

    it { is_expected.to be @fiber1 }
  end
end