describe IO do
  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  describe "#await_readable" do
    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:wait_proc) { proc do
        reader.await_readable wait_options
      end }

      let(:result) { true }

      def resume
        writer.write 'something'
        writer.close
      end
    end
  end

  describe "#await_read" do
    context "without output buffer" do
      subject { reader.await_read 10 }

      context "when it is readable" do
        before { writer.write "Hello!" }
        it { is_expected.to eq "Hello!" }
      end

      context "when it is not readable at first" do
        before { concurrently{ writer.write "Hello!" } }
        it { is_expected.to eq "Hello!" }
      end
    end

    context "with output buffer" do
      subject { reader.await_read 10, outbuf }
      let(:outbuf) { "" }

      context "when it is readable" do
        before { writer.write "Hello!" }
        it { is_expected.to be(outbuf).and eq("Hello!") }
      end

      context "when it is not readable at first" do
        before { concurrently{ writer.write "Hello!" } }
        it { is_expected.to be(outbuf).and eq("Hello!") }
      end
    end
  end

  describe "#concurrently_read" do
    subject { reader.concurrently_read(10).await_result }

    context "when it is readable" do
      before { writer.write "Hello!" }
      it { is_expected.to eq "Hello!" }
    end

    context "when it is not readable at first" do
      before { concurrently{ writer.write "Hello!" } }
      it { is_expected.to eq "Hello!" }
    end
  end

  describe "#await_writable" do
    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:wait_proc) { proc do
        writer.await_writable wait_options
      end }

      let(:result) { true }

      # jam pipe: default pipe buffer size on linux is 65536
      before { writer.write('a' * 65536) }

      def resume
        reader.read 65536 # clears the pipe
      end
    end
  end

  describe "#await_written" do
    subject { writer.await_written "Hello!" }

    after { expect(reader.read 6).to eq "Hello!" }

    context "when it is writable" do
      it { is_expected.to eq 6 }
    end

    context "when it is not writable at first" do
      before { writer.write ' '*(2**16) } # jam the pipe
      before { concurrently{ reader.readpartial 2**16 } }
      it { is_expected.to eq 6 }
    end
  end

  describe "#concurrently_write" do
    subject { writer.concurrently_write("Hello!").await_result }

    after { expect(reader.read 6).to eq "Hello!" }

    context "when it is writable" do
      it { is_expected.to eq 6 }
    end

    context "when it is not writable at first" do
      before { writer.write ' '*(2**16) } # jam the pipe
      before { concurrently{ reader.readpartial 2**16 } }
      it { is_expected.to eq 6 }
    end
  end
end