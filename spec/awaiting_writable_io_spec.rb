describe "using #await_writable in concurrent procs" do
  it_behaves_like "awaiting the result of a deferred evaluation" do
    let(:wait_proc) { proc do
      loop.await_writable(writer, wait_options)
    end }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    let(:evaluation_time) { 0.001 }
    let(:result) { true }

    # jam pipe: default pipe buffer size on linux is 65536
    before { writer.write('a' * 65536) }

    before { loop.concurrent_proc do
      loop.wait evaluation_time
      reader.read 65536 # clears the pipe
    end.call_detached }
  end
end