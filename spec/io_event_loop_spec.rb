describe IOEventLoop do
  subject(:instance) { IOEventLoop.new }

  it { is_expected.to be_a FiberedEventLoop }

  describe "#start" do
    subject { instance.start }

    context "when it has no timers and nothing to watch" do
      before { expect(instance).to receive(:stop).and_call_original }
      before { expect(instance).to receive(:trigger).with(:iteration) }
      it { is_expected.to be nil }
    end

    context "when it has nothing to watch but a timer to wait for" do
      before { instance.timers.after(0.01, &callback) }
      let(:callback) { proc{} }
      before { expect(callback).to receive(:call) }

      before { expect(instance).to receive(:trigger).with(:iteration).exactly(3).times }
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

        before { expect(instance).to receive(:trigger).with(:iteration) }
        it { is_expected.to be nil }
        after { expect(reader.read).to eq 'Wake up!' }
      end

      context "when its waiting to be writable" do
        before { instance.wait_for_writable(writer) }

        before { expect(instance).to receive(:trigger).with(:iteration) }
        it { is_expected.to be nil }
        after do
          writer.write 'Hello!'; writer.close
          expect(reader.read).to eq 'Hello!'
        end
      end
    end
  end

  describe "#attach_reader and #detach_reader" do
    subject { instance.start }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    context "when watching readability" do
      before { instance.attach_reader(reader, &callback1) }
      let(:callback1) { proc{ instance.detach_reader(reader) } }

      # make the reader readable
      before { instance.timers.after(0.01) { writer.write 'Message!' } }

      before { expect(callback1).to receive(:call).and_call_original }
      it { is_expected.to be nil }
    end
  end

  describe "#attach_writer and #detach_writer" do
    subject { instance.start }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    context "when watching writability" do
      before { instance.attach_writer(writer, &callback1) }
      let(:callback1) { proc{ instance.detach_writer(writer) } }

      before { expect(callback1).to receive(:call).and_call_original }
      it { is_expected.to be nil }
    end
  end

  describe "#wait_for_result with timeout" do
    subject do
      result = instance.wait_for_result(:id, 0.02) { RuntimeError.new "Time's up!" }
      (result.is_a? RuntimeError) ? raise(result) : result
    end

    context "when the result arrives in time" do
      before { instance.timers.after(0.01) { instance.hand_result_to(:id, :result) } }
      it { is_expected.to be :result }
    end

    context "when evaluation of result is too slow" do
      it { is_expected.to raise_error "Time's up!" }
    end
  end

  describe "#wait_for_readable" do
    subject { instance.wait_for_readable(reader, *timeout, &timeout_callback) }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    shared_examples "for readability" do
      context "when readable after some time" do
        before { instance.timers.after(0.01) { writer.write 'Wake up!' } }

        before { instance.timers.after(0.005) { expect(instance.waits_for_readable? reader).to be true } }
        it { is_expected.to be :readable }
        after { expect(instance.waits_for_readable? reader).to be false }
      end

      context "when canceled" do
        before { instance.timers.after(0.01) { instance.cancel_waiting_for_readable reader } }

        before { instance.timers.after(0.005) { expect(instance.waits_for_readable? reader).to be true } }
        it { is_expected.to be :canceled }
        after { expect(instance.waits_for_readable? reader).to be false }
      end
    end

    context "when it waits indefinitely" do
      let(:timeout) { nil }
      let(:timeout_callback) { nil }

      include_examples "for readability"

      context "when never readable" do
        # we do not have enough time to test that
      end
    end

    context "when it has a timeout" do
      let(:timeout) { 0.02 }
      let(:timeout_callback) { proc{ raise "Time's up!" } }

      include_examples "for readability"

      context "when not readable in time" do
        it { is_expected.to raise_error "Time's up!" }
      end
    end
  end

  describe "#wait_for_writable" do
    subject { instance.wait_for_writable(writer, *timeout, &timeout_callback) }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    # jam pipe: default pipe buffer size on linux is 65536
    before { writer.write('a' * 65536) }

    shared_examples "for writability" do
      context "when writability after some time" do
        before { instance.timers.after(0.01) { reader.read(65536) } } # clear the pipe

        before { instance.timers.after(0.005) { expect(instance.waits_for_writable? writer).to be true } }
        it { is_expected.to be :writable }
        after { expect(instance.waits_for_writable? writer).to be false }
      end

      context "when canceled" do
        before { instance.timers.after(0.01) { instance.cancel_waiting_for_writable writer } }

        before { instance.timers.after(0.005) { expect(instance.waits_for_writable? writer).to be true } }
        it { is_expected.to be :canceled }
        after { expect(instance.waits_for_writable? writer).to be false }
      end
    end

    context "when it waits indefinitely" do
      let(:timeout) { nil }
      let(:timeout_callback) { nil }

      include_examples "for writability"

      context "when never writable" do
        # we do not have enough time to test that
      end
    end

    context "when it has a timeout" do
      let(:timeout) { 0.02 }
      let(:timeout_callback) { proc{ raise "Time's up!" } }

      include_examples "for writability"

      context "when not writable in time" do
        it { is_expected.to raise_error "Time's up!" }
      end
    end
  end
end