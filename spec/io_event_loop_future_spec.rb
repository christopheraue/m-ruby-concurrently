describe IOEventLoop::Future do
  let(:loop) { IOEventLoop.new }

  describe "#result" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently{ :result } }

    before { expect(concurrency).not_to be_evaluated }
    after { expect(concurrency).to be_evaluated }

    context "when everything goes fine" do
      it { is_expected.to be :result }

      context "when requesting the result a second time" do
        before { concurrency.result }
        it { is_expected.to be :result }
      end
    end

    context "when resuming a fiber raises an error" do
      before { allow(Fiber.current).to receive(:transfer).and_raise FiberError, 'transfer error' }
      it { is_expected.to raise_error FiberError, 'transfer error' }
    end

    context "when the code inside the fiber raises an error" do
      let(:concurrency) { loop.concurrently{ raise 'evil error' } }
      before { expect(loop).to receive(:trigger).with(:error,
        (be_a(RuntimeError).and have_attributes message: 'evil error')) }
      it { is_expected.to raise_error RuntimeError, 'evil error' }

      context "when requesting the result a second time" do
        before { concurrency.result rescue nil }
        it { is_expected.to raise_error RuntimeError, 'evil error' }
      end
    end

    context "when getting the evaluating result from two concurrent blocks" do
      let!(:concurrency) { loop.concurrently{ loop.wait(0.0001); :result } }
      let!(:concurrency1) { loop.concurrently{ concurrency.result } }
      let!(:concurrency2) { loop.concurrently{ concurrency.result } }

      it { is_expected.to be :result }
      after { expect(concurrency1.result).to be :result }
      after { expect(concurrency2.result).to be :result }
    end
  end

  describe "#result with a timeout" do
    subject { concurrency.result options }

    let(:options) { { within: 0.0001, timeout_result: timeout_result } }
    let(:timeout_result) { :timeout_result }

    context "when the result arrives in time" do
      let(:concurrency) { loop.concurrently{ :result } }
      it { is_expected.to be :result }
    end

    context "when evaluation of result is too slow" do
      let(:concurrency) { loop.concurrently do
        loop.wait(0.0002)
        :result
      end }

      context "when no timeout result is given" do
        before { options.delete :timeout_result }
        it { is_expected.to raise_error IOEventLoop::TimeoutError, "evaluation timed out after #{options[:within]} second(s)" }
      end

      context "when the timeout result is a timeout error" do
        let(:timeout_result) { IOEventLoop::TimeoutError.new("Time's up!") }
        it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
      end

      context "when the timeout result is not an timeout error" do
        let(:timeout_result) { :timeout_result }
        it { is_expected.to be :timeout_result }
      end
    end

    context "when getting the evaluating result from two concurrent blocks, from one with a timeout" do
      subject { concurrency.result }
      let!(:concurrency) { loop.concurrently{ loop.wait(0.0002); :result } }
      let!(:concurrency1) { loop.concurrently{ concurrency.result } }
      let!(:concurrency2) { loop.concurrently{ concurrency.result within: 0.0001, timeout_result: :timeout_result } }

      it { is_expected.to be :result }
      after { expect(concurrency1.result).to be :result }
      after { expect(concurrency2.result).to be :timeout_result }
    end
  end

  describe "#cancel" do
    before { expect(concurrency).not_to be_evaluated }
    after { expect(concurrency).to be_evaluated }

    context "when doing it before requesting the result" do
      subject { concurrency.cancel *reason }

      let(:concurrency) { loop.concurrently{ :result } }

      context "when giving no explicit reason" do
        let(:reason) { nil }
        it { is_expected.to be :cancelled }
        after { expect{ concurrency.result }.to raise_error IOEventLoop::CancelledError, "evaluation cancelled" }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }
        it { is_expected.to be :cancelled }
        after { expect{ concurrency.result }.to raise_error IOEventLoop::CancelledError, "cancel reason" }
      end
    end

    context "when doing it after requesting the result" do
      subject { loop.concurrently{ concurrency.cancel *reason }.result }

      let(:concurrency) { loop.concurrently{ loop.wait(0.0001) } }

      context "when giving no explicit reason" do
        let(:reason) { nil }
        it { is_expected.to be :cancelled }
        after { expect{ concurrency.result }.to raise_error IOEventLoop::CancelledError, "evaluation cancelled" }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }
        it { is_expected.to be :cancelled }
        after { expect{ concurrency.result }.to raise_error IOEventLoop::CancelledError, "cancel reason" }
      end
    end

    context "when cancelling after it is already evaluated" do
      subject { concurrency.cancel }

      let(:concurrency) { loop.concurrently{ :result } }
      before { concurrency.result }

      it { is_expected.to raise_error IOEventLoop::Error, "already evaluated" }
    end
  end
end