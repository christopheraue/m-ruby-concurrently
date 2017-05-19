describe IO do
  before { Concurrently::EventLoop.current.reinitialize! }

  describe "#await_readable" do
    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:wait_proc) { proc do
        reader.await_readable wait_options
      end }

      let(:evaluation_time) { 0.001 }
      let(:result) { true }

      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }

      let!(:resume_proc) { concurrent_proc do
        wait evaluation_time
        writer.write result
        writer.close
      end.call_detached }
    end
  end

  describe "#await_writable" do
    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:wait_proc) { proc do
        writer.await_writable wait_options
      end }

      let(:evaluation_time) { 0.001 }
      let(:result) { true }

      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }

      # jam pipe: default pipe buffer size on linux is 65536
      before { writer.write('a' * 65536) }

      let!(:resume_proc) { concurrent_proc do
        wait evaluation_time
        reader.read 65536 # clears the pipe
      end.call_detached }
    end
  end
end