describe IOEventLoop::WritabilityFuture do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  # jam pipe: default pipe buffer size on linux is 65536
  before { writer.write('a' * 65536) }

  describe "#await" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently do
      loop.writable(writer).await
      writer.write 'test'
    end }

    context "when readable after some time" do
      before { loop.concurrently do
        loop.now_in(0.0001).await
        reader.read(65536) # clears the pipe
      end }

      it { is_expected.to be 4 }
    end
  end

  describe "#await with a timeout" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently do
      loop.writable(writer).await within: 0.0005, timeout_result: IOEventLoop::TimeoutError.new("Time's up!")
      writer.write 'test'
    end }

    context "when writable after some time" do
      before { loop.concurrently do
        loop.now_in(0.0001).await
        reader.read(65536) # clears the pipe
      end }

      it { is_expected.to be 4 }
    end

    context "when not writable in time" do
      it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
    end
  end

  describe "#cancel" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently{ future.await } }
    let(:future) { loop.writable(writer) }

    context "when doing it before awaiting it" do
      before { future.cancel }
      it { is_expected.to raise_error IOEventLoop::CancelledError, "waiting cancelled" }
    end

    context "when doing it after awaiting it" do
      before { loop.concurrently do
        loop.now_in(0.0001).await
        future.cancel
      end }

      it { is_expected.to raise_error IOEventLoop::CancelledError, "waiting cancelled" }
    end
  end
end