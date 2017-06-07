describe Concurrently::Evaluation do
  describe ".current" do
    subject { described_class.current }
    it { is_expected.to be_a described_class }
    it { is_expected.to be described_class.current } # same object for different calls
  end

  describe "#resume!" do
    subject { await_resume! }
    let!(:evaluation) { Concurrently::Evaluation.current }
    it_behaves_like "#resume!"
  end
end