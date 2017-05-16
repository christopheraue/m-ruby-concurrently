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

    context "when limiting the wait time" do
      subject { concurrent_evaluation.await_result }

      let(:wait_options) { { within: timeout_time, timeout_result: timeout_result } }
      let(:timeout_result) { :timeout_result }

      context "when the result arrives in time" do
        let(:timeout_time) { 2*evaluation_time }
        it { is_expected.to be result }
      end

      context "when evaluation of result is too slow" do
        let(:timeout_time) { 0.5*evaluation_time }

        context "when no timeout result is given" do
          before { wait_options.delete :timeout_result }
          it { is_expected.to raise_error IOEventLoop::TimeoutError, "evaluation timed out after #{wait_options[:within]} second(s)" }
        end

        context "when the timeout result is a timeout error" do
          let(:timeout_result) { IOEventLoop::TimeoutError.new("Time's up!") }
          it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
        end

        context "when the timeout result is not an timeout error" do
          let(:timeout_result) { :timeout_result }
          it { is_expected.to be :timeout_result }
        end
      end
    end
  end
end