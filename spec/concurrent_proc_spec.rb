describe IOEventLoop::ConcurrentProc do
  subject(:instance) { described_class.new(loop, *args, &block) }
  let(:loop) { IOEventLoop.new }

  let(:args) { [] }
  let(:block) { proc{} }

  it { is_expected.to be_a Proc }

  shared_examples "evaluating the block of the concurrent proc" do
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
  end

  describe "#call_detached" do
    subject(:call) { instance.call_detached *call_args }
    let(:call_args) { [] }
    it_behaves_like "evaluating the block of the concurrent proc"
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

  xdescribe "#.()" do
    subject(:call) { instance.(*call_args) }
    let(:call_args) { [] }
    it_behaves_like "evaluating the block of the concurrent proc"
  end

  xdescribe "#[]" do
    subject(:call) { instance[*call_args] }
    let(:call_args) { [] }
    it_behaves_like "evaluating the block of the concurrent proc"
  end
end