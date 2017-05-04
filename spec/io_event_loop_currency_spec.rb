describe IOEventLoop::Concurrency do
  let(:loop) { IOEventLoop.new }

  describe "#await with a timeout" do
    subject { loop.start }

    let!(:instance) { loop.once do
      begin
        @result = instance.await_result(within: 0.0002, timeout_result: timeout_result)
      rescue => e
        @result = e
      end
    end }

    let(:timeout_result) { :timeout_result }

    context "when the result arrives in time" do
      before { loop.once{ instance.resume_with :result } }
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
      let!(:instance) { loop.once{ @result = instance.await_result } }
      before { loop.once{ expect(instance.waits?).to be true }}
      before { loop.start }

      it { is_expected.not_to raise_error }
      after { expect(instance.waits?).to be false }
      after { expect(@result).to be :result }
    end

    context "when resuming a fiber raises an error" do
      # e.g. resuming the fiber raises a FiberError
      let!(:instance) { loop.once do
        allow(Fiber.current).to receive(:resume).and_raise FiberError, 'resume error'
        instance.await_result
      end }
      before { loop.start }

      it { is_expected.to raise_error FiberError, 'resume error' }
    end
  end

  describe "#cancel" do
    let!(:instance) { loop.once do
      begin
        instance.await_result
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

  describe "#await_readable" do
    subject { loop.start }

    let!(:instance) { loop.once do
      begin
        @result = instance.await_readable(reader, opts)
      rescue => e
        @result = e
        raise e
      end
    end }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    shared_examples "for readability" do
      context "when readable after some time" do
        before { loop.after(0.0001) { writer.write 'Wake up!' } }

        it { is_expected.not_to raise_error }
        after { expect(@result).to be :readable }
      end

      context "when cancelled" do
        before { loop.after(0.0001) { instance.cancel_awaiting_readable reader } }

        it { is_expected.not_to raise_error }
        after { expect(@result).to be :cancelled }
      end
    end

    context "when it waits indefinitely" do
      let(:opts) { { within: nil, timeout_result: nil } }

      include_examples "for readability"

      context "when never readable" do
        # we do not have enough time to test that
      end
    end

    context "when it has a timeout" do
      let(:opts) { { within: 0.0002, timeout_result: IOEventLoop::TimeoutError.new("Time's up!") } }

      include_examples "for readability"

      context "when not readable in time" do
        it { is_expected.to raise_error IOEventLoop::CancelledError, "Time's up!" }
        after { expect(@result).to be_a(IOEventLoop::TimeoutError).and have_attributes(message: "Time's up!") }
      end
    end
  end

  describe "#await_writable" do
    subject { loop.start }

    let!(:instance) { loop.once do
      begin
        @result = instance.await_writable(writer, opts)
      rescue => e
        @result = e
        raise e
      end
    end }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    # jam pipe: default pipe buffer size on linux is 65536
    before { writer.write('a' * 65536) }

    shared_examples "for writability" do
      context "when writable after some time" do
        before { loop.after(0.0001) { reader.read(65536) } } # clear the pipe

        it { is_expected.not_to raise_error }
        after { expect(@result).to be :writable }
      end

      context "when cancelled" do
        before { loop.after(0.0001) { instance.cancel_awaiting_writable writer } }

        it { is_expected.not_to raise_error }
        after { expect(@result).to be :cancelled }
      end
    end

    context "when it waits indefinitely" do
      let(:opts) { { within: nil, timeout_result: nil } }

      include_examples "for writability"

      context "when never writable" do
        # we do not have enough time to test that
      end
    end

    context "when it has a timeout" do
      let(:opts) { { within: 0.02, timeout_result: IOEventLoop::TimeoutError.new("Time's up!") } }

      include_examples "for writability"

      context "when not writable in time" do
        it { is_expected.to raise_error IOEventLoop::CancelledError, "Time's up!" }
        after { expect(@result).to be_a(IOEventLoop::TimeoutError).and have_attributes(message: "Time's up!") }
      end
    end
  end
end