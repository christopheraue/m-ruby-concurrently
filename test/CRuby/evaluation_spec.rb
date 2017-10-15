describe Concurrently::Evaluation do
  describe ".current" do
    subject { described_class.current }
    it { is_expected.to be_a described_class }
    it { is_expected.to be described_class.current } # same object for different calls
  end

  describe "#resume!" do
    let!(:evaluation) { Concurrently::Evaluation.current }

    context "if it is not waiting" do
      subject { evaluation.resume! }
      it { is_expected.to raise_error Concurrently::Evaluation::Error, start_with("not waiting") }
    end

    context "if it is waiting" do
      context "if it is resumed twice" do
        subject { help_eval.await_result }
        let!(:help_eval) do
          concurrently do
            evaluation.resume!
            begin
              evaluation.resume!
            rescue => e
              # rescue to the error to keep the output clean by not
              # triggering Concurrently::Proc.on :error
              e
            end
          end
        end
        before { await_resume! }
        it { is_expected.to raise_error Concurrently::Evaluation::Error, start_with("already scheduled") }
      end

      context "if it is resumed once" do
        subject { await_resume! }

        context "when given no result" do
          let!(:help_eval) { concurrently{ evaluation.resume! } }
          it { is_expected.to eq nil }
        end

        context "when given a result" do
          let!(:help_eval) { concurrently{ evaluation.resume! :result } }
          it { is_expected.to eq :result }
        end
      end
    end
  end
end