describe "using #await_writable in concurrent procs" do
  let(:loop) { IOEventLoop.new }
  let(:concurrent_evaluation) { loop.concurrent_proc(&wait_proc).call_detached }

  let(:wait_proc) { proc do
    loop.await_writable writer
    @result = writer.write 'test'
  end }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  # jam pipe: default pipe buffer size on linux is 65536
  before { writer.write('a' * 65536) }

  before { loop.concurrent_proc do
    loop.wait 0.00001
    reader.read 65536 # clears the pipe
  end.call_detached }

  context "when originating inside a concurrently block" do
    subject { @result }
    before { loop.concurrently do
      loop.await_writable writer
      @result = writer.write 'test'
      loop.manually_resume! @spec_fiber
    end }

    # We need a reference wait to ensure we wait long enough for the
    # concurrently block to finish.
    before do
      @spec_fiber = Fiber.current
      loop.await_manual_resume!
    end

    it { is_expected.to be 4 }
  end

  context "when originating inside a concurrent proc" do
    subject { concurrent_evaluation.await_result }
    it { is_expected.to be 4 }
  end

  context "when originating outside a concurrent proc" do
    subject { wait_proc.call }
    it { is_expected.to be 4 }
  end

  describe "evaluating the concurrent evaluation while it is waiting" do
    subject { concurrent_evaluation.await_result }

    before do # make sure the concurrent evaluation is started before evaluating it
      concurrent_evaluation
    end

    before { loop.concurrent_proc do
      # cancel the concurrent evaluation right away
      concurrent_evaluation.conclude_with :intercepted

      # Wait after the reader is readable to make sure the concurrent evaluation
      # is not resumed then (i.e. watching the reader is properly cancelled)
      loop.wait 0.0001
    end.call }

    it { is_expected.to be :intercepted }
  end
end