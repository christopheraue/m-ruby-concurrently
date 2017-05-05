describe IOEventLoop do
  subject(:instance) { IOEventLoop.new }

  describe "#start" do
    subject { instance.start }

    before { instance.concurrently{ expect(instance).to be_running } }
    after { expect(instance).not_to be_running }

    context "when it has no timers and nothing to watch" do
      it { is_expected.to be nil }
    end

    context "when it has nothing to watch but a timer to wait for" do
      before { instance.concurrently do
        instance.now_in(0.0001).await
        callback.call
      end }
      let(:callback) { proc{} }
      before { expect(callback).to receive(:call) }

      it { is_expected.to be nil }
    end

    context "when it has an IO object waiting for a single event" do
      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }

      context "when its waiting to be readable" do
        before { instance.concurrently do
          instance.readable(reader).await
          @result = reader.read
        end }

        before { instance.concurrently do
          instance.now_in(0.0001).await
          writer.write 'Wake up!'
          writer.close
        end }

        it { is_expected.to be nil }
        after { expect(@result).to eq 'Wake up!' }
      end

      context "when its waiting to be writable" do
        # jam pipe: default pipe buffer size on linux is 65536
        before { writer.write('a' * 65536) }

        before { instance.concurrently do
          instance.writable(writer).await
          @result = writer.write 'Hello!'
        end }

        before { instance.concurrently do
          instance.now_in(0.0001).await
          reader.read(65536) # clears the pipe
        end }

        it { is_expected.to be nil }
        after { expect(@result).to eq 6 }
      end
    end
  end

  describe "an iteration causing an error" do
    subject { instance.start }
    before { instance.concurrently{ raise 'evil error' }  }

    before { expect(instance).to receive(:trigger).with(:error,
      (be_a(RuntimeError).and have_attributes message: 'evil error')).and_call_original }

    context "when the loop should stop and raise the error (the default)" do
      it { is_expected.to raise_error 'evil error' }
    end

    context "when the loop should forgive the error" do
      before { instance.forgive_iteration_errors! }
      it { is_expected.to be nil }
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
      before { instance.concurrently do
        instance.now_in(0.0001).await
        writer.write 'Message!'
      end }

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

  describe "#watch_events" do
    subject { instance.watch_events(object, :event) }

    let(:object) { Object.new.extend CallbacksAttachable }

    it { is_expected.to be_a(IOEventLoop::EventWatcher).and having_attributes(loop: instance,
      subject: object, event: :event)}
  end
end