shared_examples_for "#resume!" do
  before { concurrent_proc do
    wait 0.0001
    @resume_result = evaluation.resume! *[result]
  end.call_nonblock }

  after { expect(@resume_result).to be :resumed }

  context "when given no result" do
    let(:result) { nil }
    it { is_expected.to eq nil }
  end

  context "when given a result" do
    let(:result) { :result }
    it { is_expected.to eq :result }

    context "when the result has a customized #==" do
      let(:result_class) do
        Struct.new(:value) do
          def ==(other)
            value == other.value
          end
        end
      end
      let(:result) { result_class.new(:value) }
      it { is_expected.to eq result }
    end
  end
end