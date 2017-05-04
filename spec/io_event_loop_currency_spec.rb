describe IOEventLoop::Concurrency do
  let(:loop) { IOEventLoop.new }

  describe "#await with a timeout" do
    subject { loop.start }

    let!(:instance) { loop.concurrently do
      begin
        @result = instance.result(within: 0.0002, timeout_result: timeout_result)
      rescue => e
        @result = e
      end
    end }

    let(:timeout_result) { :timeout_result }

    context "when the result arrives in time" do
      before { loop.concurrently{ instance.resume_with :result } }
      it { is_expected.not_to raise_error }
      after { expect(@result).to be :result }
    end

    context "when evaluation of result is too slow" do
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

  describe "#resume" do
    subject { instance.resume_with :result }

    context "when waiting originates from a fiber" do
      let!(:instance) { loop.concurrently{ @result = instance.result } }
      before { loop.start }

      it { is_expected.not_to raise_error }
      after { expect(@result).to be :result }
    end

    context "when resuming a fiber raises an error" do
      # e.g. resuming the fiber raises a FiberError
      let!(:instance) { loop.concurrently do
        allow(Fiber.current).to receive(:resume).and_raise FiberError, 'resume error'
        instance.result
      end }
      before { loop.start }

      it { is_expected.to raise_error FiberError, 'resume error' }
    end
  end

  describe "#cancel" do
    let!(:instance) { loop.concurrently do
      begin
        instance.result
      rescue IOEventLoop::CancelledError => e
        @result = e
      end
    end }
    before { loop.start }

    context "when giving no explicit reason" do
      subject { instance.cancel }

      it { is_expected.to be :cancelled }
      after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
        message: "waiting cancelled") }
    end

    context "when giving a reason" do
      subject { instance.cancel 'cancel reason' }

      it { is_expected.to be :cancelled }
      after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
        message: "cancel reason") }
    end
  end
end