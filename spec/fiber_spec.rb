describe IOEventLoop::ConcurrentProcFiber do
  let(:loop) { IOEventLoop.new }

  describe "#cancel" do
    before { @result = :not_evaluated }

    context "when doing it before its evaluation is started" do
      subject { concurrent_future.cancel }

      let!(:concurrent_future) { loop.concurrently{ @result = :evaluated } }

      it { is_expected.to be :cancelled }
      after { expect{ loop.wait 0.001; @result }.to be :not_evaluated }
    end

    context "when doing it its evaluation is started" do
      subject { loop.concurrent_future{ concurrent_future.cancel }.await_result }

      let(:concurrent_future) { loop.concurrently{ loop.wait(0.0001); @result = :evaluated } }

      it { is_expected.to be :cancelled }
      after { expect{ loop.wait 0.001; @result }.to be :not_evaluated }
    end
  end
end