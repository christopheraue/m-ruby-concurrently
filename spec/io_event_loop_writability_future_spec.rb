describe IOEventLoop::WritabilityFuture do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  # jam pipe: default pipe buffer size on linux is 65536
  before { writer.write('a' * 65536) }

  describe "#await" do
    subject { loop.start }

    before { loop.concurrently do
      loop.writable(writer).await
      @result = writer.write 'test'
    end }

    context "when readable after some time" do
      before { loop.concurrently do
        loop.now_in(0.0001).await
        reader.read(65536) # clears the pipe
      end }

      it { is_expected.not_to raise_error }
      after { expect(@result).to be 4 }
    end
  end

  describe "#await with a timeout" do
    subject { loop.start }

    before { loop.concurrently do
      begin
        loop.writable(writer).await within: 0.0005, timeout_result: IOEventLoop::TimeoutError.new("Time's up!")
        @result = writer.write 'test'
      rescue => e
        @result = e
        raise e
      end
    end }

    context "when writable after some time" do
      before { loop.concurrently do
        loop.now_in(0.0001).await
        reader.read(65536) # clears the pipe
      end }

      it { is_expected.not_to raise_error }
      after { expect(@result).to be 4 }
    end

    context "when not writable in time" do
      it { is_expected.to raise_error IOEventLoop::CancelledError, "Time's up!" }
      after { expect(@result).to be_a(IOEventLoop::TimeoutError).and have_attributes(message: "Time's up!") }
    end
  end

  describe "#cancel" do
    subject { loop.start }

    before { loop.concurrently do
      begin
        future.await
      rescue => e
        @result = e
      end
    end }
    let(:future) { loop.writable(writer) }

    context "when doing it before awaiting it" do
      before { future.cancel }

      it { is_expected.not_to raise_error }
      after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
        message: "waiting cancelled") }
    end

    context "when doing it after awaiting it" do
      before { loop.concurrently do
        loop.now_in(0.0001).await
        future.cancel
      end }

      it { is_expected.not_to raise_error }
      after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
        message: "waiting cancelled") }
    end
  end
end