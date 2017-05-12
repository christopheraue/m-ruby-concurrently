describe "using #await_readable in concurrent procs" do
  let(:loop) { IOEventLoop.new }
  let(:concurrent_proc) { loop.concurrent_proc(&wait_proc) }

  let(:wait_proc) { proc do
    loop.await_readable reader
    reader.read
  end }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }
  let(:ready_time) { 0.0001 }

  before { loop.concurrent_proc do
    loop.wait ready_time
    writer.write 'Wake up!'
    writer.close
  end }

  context "when originating inside a concurrent proc" do
    subject { concurrent_proc.await_result }
    it { is_expected.to eq 'Wake up!' }
  end

  context "when originating outside a concurrent proc" do
    subject { wait_proc.call }
    it { is_expected.to eq 'Wake up!' }
  end

  describe "evaluating the concurrent proc while it is waiting" do
    subject { concurrent_proc.await_result }

    before do # make sure the concurrent proc is started before evaluating it
      concurrent_proc
    end

    before { loop.concurrent_proc do
      # cancel the concurrent proc right away
      concurrent_proc.evaluate_to :intercepted

      # Wait after the reader is readable to make sure the concurrent proc
      # is not resumed then (i.e. watching the reader is properly cancelled)
      loop.wait ready_time
    end.await_result }

    it { is_expected.to be :intercepted }
  end
end