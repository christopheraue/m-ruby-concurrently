describe IOEventLoop::Concurrency::ReadabilityFuture do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  describe "#result with a timeout" do
    subject { loop.start }

    before { loop.concurrently do
      begin
        @result = future.result within: 0.0005, timeout_result: IOEventLoop::TimeoutError.new("Time's up!")
      rescue => e
        @result = e
        raise e
      end
    end }
    let(:future) { loop.concurrently_readable(reader) { reader.read } }

    context "when readable after some time" do
      before { loop.concurrently do
        loop.concurrently_wait 0.0001
        writer.write 'Wake up!'
        writer.close
      end }

      it { is_expected.not_to raise_error }
      after { expect(@result).to eq 'Wake up!' }
    end

    context "when not readable in time" do
      it { is_expected.to raise_error IOEventLoop::CancelledError, "Time's up!" }
      after { expect(@result).to be_a(IOEventLoop::TimeoutError).and have_attributes(message: "Time's up!") }
    end
  end

  describe "#cancel" do
    subject { loop.start }
    before { loop.concurrently do
      loop.concurrently_wait 0.0001
      @cancel_result = future.cancel
    end }

    before { loop.concurrently do
      begin
        future.result
      rescue => e
        @result = e
      end
    end }
    let(:future) { loop.concurrently_readable(reader){ :readable } }

    it { is_expected.not_to raise_error }
    after { expect(@cancel_result).to be :cancelled }
    after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
      message: "waiting cancelled") }
  end
end