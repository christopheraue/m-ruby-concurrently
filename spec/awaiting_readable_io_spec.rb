describe "using #await_readable in concurrent procs" do
  it_behaves_like "awaiting the result of a deferred evaluation" do
    let(:wait_proc) { proc do
      loop.await_readable(reader, wait_options)
    end }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    let(:evaluation_time) { 0.001 }
    let(:result) { true }

    before { loop.concurrent_proc do
      loop.wait evaluation_time
      writer.write result
      writer.close
    end.call_detached }
  end
end