describe IOEventLoop::ConcurrentBlock do
  let(:loop) { IOEventLoop.new }

  describe "the reuse of concurrent blocks" do
    subject { concurrent_block3.await_result } # let the third block finish

    let!(:concurrent_block1) { loop.concurrent_proc{ @fiber1 = Fiber.current }.call }
    let!(:concurrent_block2) { loop.concurrent_proc{ @fiber2 = Fiber.current }.call }
    before { concurrent_block2.await_result } # let the two blocks finish
    let!(:concurrent_block3) { loop.concurrent_proc{ @fiber3 = Fiber.current }.call }

    it { is_expected.not_to raise_error }

    after { expect(@fiber1).not_to be @fiber2 }
    after { expect(@fiber2).to be @fiber3 }
    after { expect(@fiber3).not_to be @fiber1 }
  end

  describe "#cancel!" do
    before { @result = :not_evaluated }

    context "when doing it before its evaluation is started" do
      subject { concurrent_block.cancel! }

      let!(:concurrent_block) { loop.concurrently{ @result = :evaluated } }

      it { is_expected.to be :cancelled }
      after { expect{ loop.wait 0.001; @result }.to be :not_evaluated }
    end

    context "when doing it its evaluation is started" do
      subject { loop.concurrent_proc{ concurrent_block.cancel! }.call.await_result }

      let(:concurrent_block) { loop.concurrently{ loop.wait(0.0001); @result = :evaluated } }

      it { is_expected.to be :cancelled }
      after { expect{ loop.wait 0.001; @result }.to be :not_evaluated }
    end
  end
end