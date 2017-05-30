describe Concurrently::Evaluation do
  describe ".current" do
    subject { described_class.current }
    it { is_expected.to be_a described_class }
    it { is_expected.to be described_class.current } # same object for different calls
  end

  describe "#schedule_resume!" do
    subject { await_scheduled_resume! }
    let!(:evaluation) { Concurrently::Evaluation.current }

    def call(*args)
      evaluation.schedule_resume! *args
    end

    it_behaves_like "#schedule_resume!"
  end
end