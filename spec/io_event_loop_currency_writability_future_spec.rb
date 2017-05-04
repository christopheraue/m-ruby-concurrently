describe IOEventLoop::Concurrency::WritabilityFuture do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  # jam pipe: default pipe buffer size on linux is 65536
  before { writer.write('a' * 65536) }

  describe "#result with a timeout" do
    subject { loop.start }

    let!(:instance) { loop.concurrently_writable(writer) do
      begin
        @result = instance.result within: 0.0002, timeout_result: IOEventLoop::TimeoutError.new("Time's up!")
      rescue => e
        @result = e
        raise e
      end
    end }

    context "when writable after some time" do
      before { loop.concurrently(after: 0.0001) { reader.read(65536) } } # clear the pipe

      it { is_expected.not_to raise_error }
      after { expect(@result).to be :writable }
    end

    context "when not writable in time" do
      it { is_expected.to raise_error IOEventLoop::CancelledError, "Time's up!" }
      after { expect(@result).to be_a(IOEventLoop::TimeoutError).and have_attributes(message: "Time's up!") }
    end
  end

  describe "#cancel" do
    subject { loop.start }

    let!(:instance) { loop.concurrently_writable(writer) do
      begin
        @result = instance.result
      rescue => e
        @result = e
        raise e
      end
    end }

    before { loop.concurrently(after: 0.0001) { instance.cancel } }

    it { is_expected.not_to raise_error }
    after { expect(@result).to be :cancelled }
  end
end