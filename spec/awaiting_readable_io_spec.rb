describe "using #await_readable in concurrent procs" do
  it_behaves_like "awaiting the result of a deferred evaluation" do
    let(:wait_proc) { proc do
      loop.await_readable reader
      reader.read
    end }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    let(:result) { 'Wake up!' }

    before { loop.concurrent_proc do
      loop.wait 0.0001
      writer.write result
      writer.close
    end.call_detached }
  end
end