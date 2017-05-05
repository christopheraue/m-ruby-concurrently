describe IOEventLoop::Concurrency::WritabilityFuture do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  # jam pipe: default pipe buffer size on linux is 65536
  before { writer.write('a' * 65536) }

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
    let(:future) { loop.concurrently_writable(writer) { writer.write 'test' } }

    context "when writable after some time" do
      before { loop.concurrently do
        loop.concurrently_wait 0.0001
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
    let(:future) { loop.concurrently_writable(writer){ :writable } }

    it { is_expected.not_to raise_error }
    after { expect(@cancel_result).to be :cancelled }
    after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
      message: "waiting cancelled") }
  end
end