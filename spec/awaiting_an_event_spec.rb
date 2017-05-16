describe "using #await_event in concurrent procs" do
  it_behaves_like "awaiting the result of a deferred evaluation" do
    let(:wait_proc) { proc{ loop.await_event object, :event } }

    let(:object) { Object.new.extend CallbacksAttachable }

    before { loop.concurrent_proc do
      loop.wait evaluation_time
      object.trigger :event, result
    end.call_detached }
  end
end