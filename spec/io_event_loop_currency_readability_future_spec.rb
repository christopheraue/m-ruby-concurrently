describe IOEventLoop::Concurrency::ReadabilityFuture do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  describe "#result with a timeout" do
    subject { loop.start }

    let!(:instance) { loop.concurrently_readable(reader) do
      begin
        @result = instance.result within: 0.0002, timeout_result: IOEventLoop::TimeoutError.new("Time's up!")
      rescue => e
        @result = e
        raise e
      end
    end }

    context "when readable after some time" do
      before { loop.concurrently(after: 0.0001) { writer.write 'Wake up!' } }

      it { is_expected.not_to raise_error }
      after { expect(@result).to be :readable }
    end

    context "when not readable in time" do
      it { is_expected.to raise_error IOEventLoop::CancelledError, "Time's up!" }
      after { expect(@result).to be_a(IOEventLoop::TimeoutError).and have_attributes(message: "Time's up!") }
    end
  end

  describe "#cancel" do
    subject { loop.start }

    let!(:instance) { loop.concurrently_readable(reader) do
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