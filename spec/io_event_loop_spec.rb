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

    context "when it has an IO object waiting" do
      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }

      context "when its waiting to be readable" do
        before { instance.timers.after(0.01) { writer.write 'Wake up!'; writer.close } }
        before { instance.wait_for(reader, :r) }

        it { is_expected.to be nil }
        after { expect(reader.read).to eq 'Wake up!' }
      end

      context "when its waiting to be writable" do
        before { instance.wait_for(writer, :w) }

        it { is_expected.to be nil }
        after do
          writer.write 'Hello!'; writer.close
          expect(reader.read).to eq 'Hello!'
        end
      end
    end
  end
end