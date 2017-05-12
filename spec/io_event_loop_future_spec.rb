describe IOEventLoop::ConcurrentProc do
  let(:loop) { IOEventLoop.new }

  describe "#await_result" do
    subject { concurrent_proc.await_result(&with_result) }

    let(:concurrent_proc) { loop.concurrent_proc{ result } }
    let(:with_result) { nil }
    let(:result) { :result }

    before { expect(concurrent_proc).not_to be_evaluated }
    after { expect(concurrent_proc).to be_evaluated }

    context "when everything goes fine" do
      it { is_expected.to be :result }

      context "when requesting the result a second time" do
        before { concurrent_proc.await_result }
        it { is_expected.to be :result }
      end

      context "when a block to do something with the result is given" do
        context "when transforming to a non-error value" do
          let(:with_result) { proc{ |result| "transformed #{result} to result" } }
          it { is_expected.to eq "transformed result to result" }
        end

        context "when transforming to an error value" do
          let(:with_result) { proc{ |result| RuntimeError.new("transformed #{result} to error") } }
          it { is_expected.to raise_error RuntimeError, 'transformed result to error' }
        end
      end

      context "when the result is an array" do
        let(:result) { %i(a b c) }
        it { is_expected.to eq %i(a b c) }
      end
    end

    context "when resuming a fiber raises an error" do
      before { allow(Fiber).to receive(:yield).and_raise FiberError, 'fiber error' }
      it { is_expected.to raise_error FiberError, 'fiber error' }
    end

    context "when the code inside the fiber raises an error" do
      let(:concurrent_proc) { loop.concurrent_proc{ raise 'error' } }
      before { expect(loop).to receive(:trigger).with(:error,
        (be_a(RuntimeError).and have_attributes message: 'error')) }
      it { is_expected.to raise_error RuntimeError, 'error' }

      context "when requesting the result a second time" do
        before { concurrent_proc.await_result rescue nil }
        it { is_expected.to raise_error RuntimeError, 'error' }
      end

      context "when a block to do something with the result is given" do
        context "when transforming to a non-error value" do
          let(:with_result) { proc{ |result| "transformed #{result} to result" } }
          it { is_expected.to eq "transformed error to result" }
        end

        context "when transforming to an error value" do
          let(:with_result) { proc{ |result| RuntimeError.new("transformed #{result} to error") } }
          it { is_expected.to raise_error RuntimeError, 'transformed error to error' }
        end
      end
    end

    context "when getting the evaluating result from two concurrent procs" do
      let!(:concurrent_proc) { loop.concurrent_proc{ loop.wait(0.0001); :result } }
      let!(:concurrent_proc1) { loop.concurrent_proc{ concurrent_proc.await_result } }
      let!(:concurrent_proc2) { loop.concurrent_proc{ concurrent_proc.await_result } }

      it { is_expected.to be :result }
      after { expect(concurrent_proc1.await_result).to be :result }
      after { expect(concurrent_proc2.await_result).to be :result }
    end
  end

  describe "#await_result with a timeout" do
    subject { concurrent_proc.await_result options }

    let(:options) { { within: 0.0001, timeout_result: timeout_result } }
    let(:timeout_result) { :timeout_result }

    context "when the result arrives in time" do
      let(:concurrent_proc) { loop.concurrent_proc{ :result } }
      it { is_expected.to be :result }
    end

    context "when evaluation of result is too slow" do
      let(:concurrent_proc) { loop.concurrent_proc do
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

    context "when getting the evaluating result from two concurrent procs, from one with a timeout" do
      subject { concurrent_proc.await_result }
      let!(:concurrent_proc) { loop.concurrent_proc{ loop.wait(0.0002); :result } }
      let!(:concurrent_proc1) { loop.concurrent_proc{ concurrent_proc.await_result } }
      let!(:concurrent_proc2) { loop.concurrent_proc{ concurrent_proc.await_result within: 0.0001, timeout_result: :timeout_result } }

      it { is_expected.to be :result }
      after { expect(concurrent_proc1.await_result).to be :result }
      after { expect(concurrent_proc2.await_result).to be :timeout_result }
    end
  end

  describe "#cancel" do
    before { expect(concurrent_proc).not_to be_evaluated }
    after { expect(concurrent_proc).to be_evaluated }

    context "when doing it before requesting the result" do
      subject { concurrent_proc.cancel *reason }

      let(:concurrent_proc) { loop.concurrent_proc{ :result } }

      context "when giving no explicit reason" do
        let(:reason) { nil }
        it { is_expected.to be :cancelled }
        after { expect{ concurrent_proc.await_result }.to raise_error IOEventLoop::CancelledError, "evaluation cancelled" }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }
        it { is_expected.to be :cancelled }
        after { expect{ concurrent_proc.await_result }.to raise_error IOEventLoop::CancelledError, "cancel reason" }
      end
    end

    context "when doing it after requesting the result" do
      subject { loop.concurrent_proc{ concurrent_proc.cancel *reason }.await_result }

      let(:concurrent_proc) { loop.concurrent_proc{ loop.wait(0.0001) } }

      context "when giving no explicit reason" do
        let(:reason) { nil }
        it { is_expected.to be :cancelled }
        after { expect{ concurrent_proc.await_result }.to raise_error IOEventLoop::CancelledError, "evaluation cancelled" }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }
        it { is_expected.to be :cancelled }
        after { expect{ concurrent_proc.await_result }.to raise_error IOEventLoop::CancelledError, "cancel reason" }
      end
    end

    context "when cancelling after it is already evaluated" do
      subject { concurrent_proc.cancel }

      let(:concurrent_proc) { loop.concurrent_proc{ :result } }
      before { concurrent_proc.await_result }

      it { is_expected.to raise_error IOEventLoop::Error, "already evaluated" }
    end
  end

  context "when it configures no custom concurrent proc" do
    subject(:concurrent_proc) { loop.concurrent_proc }

    it { is_expected.to be_a(IOEventLoop::ConcurrentProc).and have_attributes(data: {}) }
    it { expect(concurrent_proc.data).to be_frozen }
  end

  context "when it configures a custom concurrent proc" do
    subject(:concurrent_proc) { loop.concurrent_proc(custom_future_class, { opt: :ion }) }

    let(:custom_future_class) { Class.new(IOEventLoop::ConcurrentProc) }

    it { is_expected.to be_a(custom_future_class).and have_attributes(data: { opt: :ion }) }
    it { expect(concurrent_proc.data).to be_frozen }
  end
end