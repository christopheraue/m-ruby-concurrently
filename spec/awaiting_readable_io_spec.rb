describe "using #await_readable in concurrent blocks" do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  describe "waiting indefinitely" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently do
      loop.await_readable reader
      reader.read
    end }

    context "when readable after some time" do
      before { loop.concurrently do
        loop.wait 0.0001
        writer.write 'Wake up!'
        writer.close
      end }

      it { is_expected.to eq 'Wake up!' }
    end
  end

  describe "waiting with a timeout" do
    subject { concurrency.result }

    let(:concurrency) { loop.concurrently do
      loop.await_readable reader, within: 0.0005
    end }

    context "when readable after some time" do
      before { loop.concurrently do
        loop.wait 0.0001
        writer.write 'Wake up!'
        writer.close
      end }

      it { is_expected.to be true }
    end

    context "when not readable in time" do
      it { is_expected.to be false }
    end
  end
end