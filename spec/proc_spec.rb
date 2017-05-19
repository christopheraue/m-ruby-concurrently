describe Concurrently::Proc do
  subject(:instance) { described_class.new(*args, &block) }
  before { Concurrently::EventLoop.current.reinitialize! }

  let(:args) { [] }
  let(:block) { proc{} }

  it { is_expected.to be_a Proc }

  describe "#call and its variants" do
    subject(:call) { instance.call *call_args }

    shared_examples "evaluating a synchronous call" do
      let(:call_args) { [:arg1, :arg2] }

      context "if the block does not need to wait during evaluation" do
        let(:block) { proc{ |*args| args } }
        it { is_expected.to eq call_args }
      end

      context "if the block needs to wait during evaluation" do
        let(:block) { proc{ |*args| wait 0.0001; args } }
        it { is_expected.to eq call_args }
      end

      xcontext "when resuming its fiber raises an error" do
        before { allow(Fiber).to receive(:yield).and_raise FiberError, 'fiber error' }
        it { is_expected.to raise_error FiberError, 'fiber error' }
      end

      context "when the code inside the block raises an error" do
        let(:block) { proc{ raise 'error' } }
        it { is_expected.to raise_error RuntimeError, 'error' }
      end
    end

    it_behaves_like "evaluating a synchronous call"

    describe "#.()" do
      subject(:call) { instance.(*call_args) }
      it_behaves_like "evaluating a synchronous call"
    end

    describe "#[]" do
      subject(:call) { instance[*call_args] }
      it_behaves_like "evaluating a synchronous call"
    end
  end

  describe "#call_nonblock" do
    subject(:call) { instance.call_nonblock *call_args }
    let(:call_args) { [:arg1, :arg2] }

    context "if the block does not need to wait during evaluation" do
      let(:block) { proc{ |*args| args } }
      it { is_expected.to eq call_args }

      context "when the code inside the block raises an error" do
        let(:block) { proc{ raise 'error' } }
        it { is_expected.to raise_error RuntimeError, 'error' }
      end
    end

    context "if the block needs to wait during evaluation" do
      let(:block) { proc{ |*args| wait 0.0001; args } }
      it { is_expected.to be_a(Concurrently::Proc::Evaluation) }

      describe "the result of the evaluation" do
        subject { call.await_result }
        it { is_expected.to eq call_args }

        context "when the code inside the block raises an error" do
          let(:block) { proc{ wait 0.0001; raise 'error' } }
          it { is_expected.to raise_error RuntimeError, 'error' }
        end
      end
    end
  end

  describe "#call_detached" do
    subject(:call) { instance.call_detached *call_args }
    let(:call_args) { [] }

    context "when it configures no custom evaluation" do
      it { is_expected.to be_a(Concurrently::Proc::Evaluation).and have_attributes(data: {}) }
    end

    context "when it configures a custom evaluation" do
      let(:args) { [custom_evaluation_class] }
      let(:custom_evaluation_class) { Class.new(Concurrently::Proc::Evaluation) }
      it { is_expected.to be_a(custom_evaluation_class).and have_attributes(data: {}) }
    end

    context "when awaiting its result" do
      subject { call.await_result }
      let(:block) { proc{ |*args| args } }
      let(:call_args) { [:arg1, :arg2] }
      it { is_expected.to eq call_args }

      context "when the code inside the block raises an error" do
        let(:block) { proc{ raise 'error' } }
        it { is_expected.to raise_error RuntimeError, 'error' }
      end
    end

    describe "the reuse of proc fibers" do
      subject { @fiber3 }

      let!(:evaluation1) { concurrent_proc{ @fiber1 = Fiber.current }.call_detached }
      let!(:evaluation2) { concurrent_proc{ @fiber2 = Fiber.current }.call_detached }
      before { evaluation2.await_result } # let the two blocks finish
      let!(:evaluation3) { concurrent_proc{ @fiber3 = Fiber.current }.call_detached }
      before { evaluation3.await_result } # let the third block finish

      it { is_expected.to be @fiber2 }
      after { expect(subject).not_to be @fiber1 }
    end
  end

  describe "#call_detached!" do
    it_behaves_like "#concurrently" do
      def call(*args, &block)
        concurrent_proc(&block).call_detached! *args
      end
    end
  end
end