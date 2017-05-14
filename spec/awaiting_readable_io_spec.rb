describe "using #await_readable in concurrent procs" do
  let(:loop) { IOEventLoop.new }
  let(:concurrent_evaluation) { loop.concurrent_proc(&wait_proc).call }

  let(:wait_proc) { proc do
    loop.await_readable reader
    @result = reader.read
  end }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  before { loop.concurrent_proc do
    writer.write 'Wake up!'
    writer.close
  end.call }

  context "when originating inside a concurrently block" do
    subject { @result }
    before { loop.concurrently(&wait_proc) }

    # We need a reference concurrent block whose result we can await to
    # ensure we wait long enough for the concurrently block to finish.
    before { loop.concurrent_proc{ loop.wait 0.0001 }.call.await_result }

    it { is_expected.to eq 'Wake up!' }
  end

  context "when originating inside a concurrent proc" do
    subject { concurrent_evaluation.await_result }
    it { is_expected.to eq 'Wake up!' }
  end

  context "when originating outside a concurrent proc" do
    subject { wait_proc.call }
    it { is_expected.to eq 'Wake up!' }
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
    end.call.await_result }

    it { is_expected.to be :intercepted }
  end
end