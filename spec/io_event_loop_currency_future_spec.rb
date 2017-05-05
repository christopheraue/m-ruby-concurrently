describe IOEventLoop::Concurrency::Future do
  let(:loop) { IOEventLoop.new }

  describe "#result" do
    subject { loop.start }

    context "when everything goes fine" do
      before { loop.concurrently do
        begin
          @result = loop.concurrently{ :result }.result
        rescue => e
          @result = e
        end
      end }
      it { is_expected.not_to raise_error }
      after { expect(@result).to be :result }
    end

    context "when resuming a fiber raises an error" do
      # e.g. resuming the fiber raises a FiberError
      before { loop.concurrently do
        begin
          allow(Fiber.current).to receive(:transfer).and_raise FiberError, 'transfer error'
          loop.concurrently{ :result }.result
        end
      end }

      it { is_expected.to raise_error IOEventLoop::CancelledError, 'transfer error' }
    end
  end

  describe "#result with a timeout" do
    subject { loop.start }

    before { loop.concurrently do
      begin
        @result = future.result within: 0.0001, timeout_result: timeout_result
      rescue => e
        @result = e
      end
    end }

    let(:timeout_result) { :timeout_result }

    context "when the result arrives in time" do
      let(:future) { loop.concurrently{ :result } }
      it { is_expected.not_to raise_error }
      after { expect(@result).to be :result }
    end

    context "when evaluation of result is too slow" do
      let(:future) { loop.concurrently do
        loop.now_in(0.0002).await
        :result
      end }

      context "when the timeout result is a timeout error" do
        let(:timeout_result) { IOEventLoop::TimeoutError.new("Time's up!") }
        it { is_expected.not_to raise_error }
        after { expect(@result).to be_a(IOEventLoop::TimeoutError).and have_attributes(message: "Time's up!") }
      end

      context "when the timeout result is not an timeout error" do
        let(:timeout_result) { :timeout_result }
        it { is_expected.not_to raise_error }
        after { expect(@result).to be :timeout_result }
      end
    end
  end

  describe "#cancel" do
    subject { loop.start }
    before { loop.concurrently do
      loop.now_in(0.0001).await
      future.cancel *reason
    end }

    before { loop.concurrently do
      begin
        future.result
      rescue IOEventLoop::CancelledError => e
        @result = e
      end
    end }
    let(:future) { loop.concurrently do
      loop.now_in(0.0002).await
      :result
    end }

    context "when giving no explicit reason" do
      let(:reason) { nil }
      it { is_expected.not_to raise_error }
      after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
        message: "waiting cancelled") }
    end

    context "when giving a reason" do
      let(:reason) { 'cancel reason' }

      it { is_expected.not_to raise_error }
      after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
        message: "cancel reason") }
    end
  end
end