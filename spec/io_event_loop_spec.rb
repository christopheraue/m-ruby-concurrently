describe IOEventLoop do
  subject(:instance) { IOEventLoop.new }

  it { is_expected.to be_a FiberedEventLoop }

  describe "#start" do
    subject { instance.start }

    context "when it has no timers and nothing to watch" do
      before { expect(instance).to receive(:stop).and_call_original }
      it { is_expected.to be nil }
    end

    context "when it has nothing to watch but a timer to wait for" do
      before { instance.timers.after(0.01, &callback) }
      let(:callback) { proc{} }
      before { expect(callback).to receive(:call) }

      before { expect(instance).to receive(:stop).and_call_original }
      it { is_expected.to be nil }
    end

    context "when it has an IO object waiting for a single event" do
      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }

      context "when its waiting to be readable" do
        before { instance.timers.after(0.01) { writer.write 'Wake up!'; writer.close } }
        before { instance.wait_for_readable(reader) }

        it { is_expected.to be nil }
        after { expect(reader.read).to eq 'Wake up!' }
      end

      context "when its waiting to be writable" do
        before { instance.wait_for_writable(writer) }

        it { is_expected.to be nil }
        after do
          writer.write 'Hello!'; writer.close
          expect(reader.read).to eq 'Hello!'
        end
      end
    end
  end

  # attaching and detaching readers and writers is implicitly tested while
  # testing #wait_for_{readable,writable}
  it { is_expected.to respond_to :attach_reader }
  it { is_expected.to respond_to :detach_reader }
  it { is_expected.to respond_to :attach_writer }
  it { is_expected.to respond_to :detach_writer }

  describe "#wait_for_result with timeout" do
    subject { instance.wait_for_result(:id, 0.02) { raise "Time's up!" } }

    context "when the result arrives in time" do
      before { instance.timers.after(0.01) { instance.hand_result_to(:id, :result) } }
      it { is_expected.to be :result }
    end

    context "when evaluation of result is too slow" do
      it { is_expected.to raise_error "Time's up!" }
    end
  end
end