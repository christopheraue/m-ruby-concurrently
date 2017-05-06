describe IOEventLoop::ReadabilityFuture do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  describe "#await" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently do
      loop.readable(reader).await
      reader.read
    end }

    context "when readable after some time" do
      before { loop.concurrently do
        loop.now_in(0.0001).await
        writer.write 'Wake up!'
        writer.close
      end }

      it { is_expected.to eq 'Wake up!' }
    end
  end

  describe "#await with a timeout" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently do
      loop.readable(reader).await within: 0.0005, timeout_result: IOEventLoop::TimeoutError.new("Time's up!")
      reader.read
    end }

    context "when readable after some time" do
      before { loop.concurrently do
        loop.now_in(0.0001).await
        writer.write 'Wake up!'
        writer.close
      end }

      it { is_expected.to eq 'Wake up!' }
    end

    context "when not readable in time" do
      it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
    end
  end

  describe "#cancel" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently{ future.await } }
    let(:future) { loop.readable(reader) }

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