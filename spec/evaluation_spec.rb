describe Concurrently::Evaluation do
  describe "#schedule_resume!" do
    subject { await_scheduled_resume! }
    let!(:evaluation) { Concurrently::Evaluation.current }

    def call(*args)
      evaluation.schedule_resume! *args
    end

    it_behaves_like "#schedule_resume!"
  end
end