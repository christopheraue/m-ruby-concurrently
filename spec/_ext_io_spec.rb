describe IO do
  before { Concurrently::EventLoop.current.reinitialize! }

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
end