describe IOEventLoop::ConcurrentBlock do
  let(:loop) { IOEventLoop.new }

  describe "the reuse of concurrent blocks" do
    subject { loop.concurrent_future{ loop.wait 0.0001 }.await_result }

    let!(:concurrent_block1) { loop.concurrently{ @result1 = :evaluated1 } }
    let!(:concurrent_block2) { loop.concurrently{ @result2 = :evaluated2 } }
    before { loop.wait 0.0001 } # let the two blocks finish
    let!(:concurrent_block3) { loop.concurrently{ @result3 = :evaluated3 } }

    it { is_expected.not_to raise_error }

    after { expect(concurrent_block1).not_to be concurrent_block2 }
    after { expect(concurrent_block2).to be concurrent_block3 }
    after { expect(concurrent_block3).not_to be concurrent_block1 }
    after { expect(@result1).to be :evaluated1 }
    after { expect(@result2).to be :evaluated2 }
    after { expect(@result3).to be :evaluated3 }
  end

  describe "#cancel" do
    before { @result = :not_evaluated }

    context "when doing it before its evaluation is started" do
      subject { concurrent_block.cancel }

      let!(:concurrent_block) { loop.concurrently{ @result = :evaluated } }

      it { is_expected.to be :cancelled }
      after { expect{ loop.wait 0.001; @result }.to be :not_evaluated }
    end

    context "when doing it its evaluation is started" do
      subject { loop.concurrent_future{ concurrent_block.cancel }.await_result }

      let(:concurrent_block) { loop.concurrently{ loop.wait(0.0001); @result = :evaluated } }

      it { is_expected.to be :cancelled }
      after { expect{ loop.wait 0.001; @result }.to be :not_evaluated }
    end
  end
end