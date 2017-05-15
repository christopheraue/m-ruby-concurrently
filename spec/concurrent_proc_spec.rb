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

  describe "#call" do
    subject(:call) { instance.call *call_args }
    let(:call_args) { [] }
    it_behaves_like "evaluating the block of the concurrent proc"
  end

  describe "#.()" do
    subject(:call) { instance.(*call_args) }
    let(:call_args) { [] }
    it_behaves_like "evaluating the block of the concurrent proc"
  end

  describe "#[]" do
    subject(:call) { instance[*call_args] }
    let(:call_args) { [] }
    it_behaves_like "evaluating the block of the concurrent proc"
  end
end