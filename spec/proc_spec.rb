describe Concurrently::Proc do
  subject(:instance) { described_class.new(*args, &block) }

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

      context "when starting/resuming the fiber raises an error" do
        let(:fiber) { Concurrently::Proc::Fiber.new(:fiber_pool){} }
        before { allow(fiber).to receive(:resume).and_raise(FiberError, 'resume error') }
        before { allow(Concurrently::EventLoop.current).to receive(:proc_fiber_pool).and_return([fiber]) }

        it { is_expected.to raise_error FiberError, 'resume error' }

        # recover from the teared down event loop caused by the error for further
        # tests
        after { Concurrently::EventLoop.current.reinitialize! }
      end

      context "when the code inside the block raises an error" do
        let(:block) { proc{ raise StandardError, 'error' } }

        before { expect(instance).to receive(:trigger).with(:error,
          (be_a(StandardError).and have_attributes message: 'error')) }
        it { is_expected.to raise_error StandardError, 'error' }
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
        let(:block) { proc{ raise StandardError, 'error' } }

        before { expect(instance).to receive(:trigger).with(:error,
          (be_a(StandardError).and have_attributes message: 'error')) }
        it { is_expected.to raise_error StandardError, 'error' }
      end
    end

    context "if the block needs to wait during evaluation" do
      let(:block) { proc{ |*args| wait 0; args } }
      it { is_expected.to be_a(Concurrently::Proc::Evaluation) }

      describe "the result of the evaluation" do
        subject { call.await_result }
        it { is_expected.to eq call_args }

        context "when the code inside the block raises an error" do
          let(:block) { proc{ wait 0; raise StandardError, 'error' } }

          before { expect(instance).to receive(:trigger).with(:error,
            (be_a(StandardError).and have_attributes message: 'error')) }
          it { is_expected.to raise_error StandardError, 'error' }
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

      context "when starting/resuming the fiber raises an error" do
        let(:fiber_pool) { [] }
        let!(:fiber) { Concurrently::Proc::Fiber.new(fiber_pool) }
        before { allow(fiber).to receive(:resume).and_raise(FiberError, 'resume error') }
        before { allow(Concurrently::Proc::Fiber).to receive(:new).and_return(fiber) }
        before { allow(Concurrently::EventLoop.current).to receive(:proc_fiber_pool).and_return(fiber_pool) }

        it { is_expected.to raise_error(Concurrently::Error, "Event loop teared down (FiberError: resume error)") }

        # recover from the teared down event loop caused by the error for further
        # tests
        after { Concurrently::EventLoop.current.reinitialize! }
      end

      context "when the code inside the block raises an error" do
        let(:block) { proc{ raise 'error' } }

        before { expect(instance).to receive(:trigger).with(:error,
          (be_a(StandardError).and have_attributes message: 'error')) }
        it { is_expected.to raise_error StandardError, 'error' }
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

  describe "#call_and_forget" do
    it_behaves_like "#concurrently" do
      def call(*args, &block)
        concurrent_proc(&block).call_and_forget *args
      end
    end
  end
end