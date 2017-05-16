describe "using #await_manual_resume! in concurrent procs" do
  it_behaves_like "awaiting the result of a deferred evaluation" do
    let(:wait_proc) { proc do
      @spec_fiber = Fiber.current
      loop.await_manual_resume! wait_options
    end }

    before { loop.concurrent_proc do
      loop.wait evaluation_time
      loop.manually_resume! @spec_fiber, :result
    end.call_detached }
  end
end