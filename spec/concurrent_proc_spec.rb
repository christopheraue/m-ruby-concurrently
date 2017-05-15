describe IOEventLoop::ConcurrentProc do
  subject(:instance) { described_class.new(loop, *args, &block) }
  let(:loop) { IOEventLoop.new }

  let(:args) { [] }
  let(:block) { proc{} }

  it { is_expected.to be_a Proc }

  describe "#call_detached" do
    subject(:call) { instance.call_detached *call_args }
    let(:call_args) { [] }

    context "when it configures no custom evaluation" do
      it { is_expected.to be_a(IOEventLoop::ConcurrentEvaluation).and have_attributes(data: {}) }
    end

    context "when it configures a custom evaluation" do
      let(:args) { [custom_evaluation_class] }
      let(:custom_evaluation_class) { Class.new(IOEventLoop::ConcurrentEvaluation) }
      it { is_expected.to be_a(custom_evaluation_class).and have_attributes(data: {}) }
    end

    context "when called with arguments" do
      subject { call.await_result }
      let(:block) { proc{ |*args| args } }
      let(:call_args) { [:arg1, :arg2] }
      it { is_expected.to eq call_args }
    end

    describe "the reuse of concurrent blocks" do
      subject { @fiber3 }

      let!(:concurrent_block1) { loop.concurrent_proc{ @fiber1 = Fiber.current }.call_detached }
      let!(:concurrent_block2) { loop.concurrent_proc{ @fiber2 = Fiber.current }.call_detached }
      before { concurrent_block2.await_result } # let the two blocks finish
      let!(:concurrent_block3) { loop.concurrent_proc{ @fiber3 = Fiber.current }.call_detached }
      before { concurrent_block3.await_result } # let the third block finish

      it { is_expected.to be @fiber2 }
      after { expect(subject).not_to be @fiber1 }
    end
  end

  describe "#call_detached!" do
    context "when called with arguments" do
      subject { @result }

      before { instance.call_detached! *call_args }
      let(:call_args) { [:arg1, :arg2] }

      let(:block) { proc do |*args|
        @result = args
        loop.manually_resume! @spec_fiber
      end }

      # We need a reference wait to ensure we wait long enough for the
      # concurrently block to finish.
      before do
        @spec_fiber = Fiber.current
        loop.await_manual_resume!
      end

      it { is_expected.to eq call_args }
    end

    describe "the reuse of concurrent blocks" do
      subject { @fiber3 }

      let!(:concurrent_block1) { loop.concurrent_proc{ @fiber1 = Fiber.current }.call_detached! }
      let!(:concurrent_block2) { loop.concurrent_proc{ @fiber2 = Fiber.current }.call_detached }
      before { concurrent_block2.await_result } # let the two blocks finish
      let!(:concurrent_block3) { loop.concurrent_proc do
        @fiber3 = Fiber.current
        loop.manually_resume! @spec_fiber
      end.call_detached! }

      # We need a reference wait to ensure we wait long enough for the
      # concurrently block to finish.
      before do
        @spec_fiber = Fiber.current
        loop.await_manual_resume!
      end

      it { is_expected.to be @fiber2 }
      after { expect(subject).not_to be @fiber1 }
    end
  end

  describe "#call_nonblock" do
    subject(:call) { instance.call_nonblock *call_args }
    let(:call_args) { [:arg1, :arg2] }

    context "if the block does not need to wait during evaluation" do
      let(:block) { proc{ |*args| args } }
      it { is_expected.to eq call_args }
    end

    context "if the block needs to wait during evaluation" do
      let(:block) { proc{ |*args| loop.wait 0.0001; args } }
      it { is_expected.to be_a(IOEventLoop::ConcurrentEvaluation) }

      describe "the result of the evaluation" do
        subject { call.await_result }
        it { is_expected.to eq call_args }
      end
    end
  end

  shared_examples "evaluating the call synchronously" do
    let(:call_args) { [:arg1, :arg2] }

    context "if the block does not need to wait during evaluation" do
      let(:block) { proc{ |*args| args } }
      it { is_expected.to eq call_args }
    end

    context "if the block needs to wait during evaluation" do
      let(:block) { proc{ |*args| loop.wait 0.0001; args } }
      it { is_expected.to eq call_args }
    end
  end

  describe "#call" do
    subject(:call) { instance.call *call_args }
    it_behaves_like "evaluating the call synchronously"
  end

  describe "#.()" do
    subject(:call) { instance.(*call_args) }
    it_behaves_like "evaluating the call synchronously"
  end

  describe "#[]" do
    subject(:call) { instance[*call_args] }
    it_behaves_like "evaluating the call synchronously"
  end
end