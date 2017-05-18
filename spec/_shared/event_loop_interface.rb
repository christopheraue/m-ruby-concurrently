shared_examples_for "EventLoop#concurrently" do
  let(:call_args) { [:arg1, :arg2] }

  context "when called with arguments" do
    subject { @result }

    before { call do |*args|
      @result = args
      loop.manually_resume! @spec_fiber
    end }

    # We need a reference wait to ensure we wait long enough for the
    # evaluation to finish.
    before do
      @spec_fiber = Fiber.current
      loop.await_manual_resume!
    end

    it { is_expected.to eq call_args }
  end

  context "when the code inside the block raises an error" do
    subject { call{ raise 'error' }; loop.wait 0.0001 }

    before { expect(loop).to receive(:trigger).with(:error,
      (be_a(RuntimeError).and have_attributes message: 'error')) }
    it { is_expected.to raise_error RuntimeError, 'error' }
  end

  describe "the reuse of proc fibers" do
    subject { @fiber3 }

    let!(:evaluation1) { call{ @fiber1 = Fiber.current } }
    let!(:evaluation2) { loop.concurrent_proc{ @fiber2 = Fiber.current }.call_detached }
    before { evaluation2.await_result } # let the two blocks finish
    let!(:evaluation3) { call do
      @fiber3 = Fiber.current
      loop.manually_resume! @spec_fiber
    end }

    # We need a reference wait to ensure we wait long enough for the
    # evaluation to finish.
    before do
      @spec_fiber = Fiber.current
      loop.await_manual_resume!
    end

    it { is_expected.to be @fiber2 }
    after { expect(subject).not_to be @fiber1 }
  end
end

shared_examples_for "EventLoop#concurrent_proc" do
  it { is_expected.to be_a(Concurrently::Proc).and have_attributes(call_detached: be_a(Concurrently::Proc::Evaluation)) }
end

shared_examples_for "EventLoop#await_manual_resume!" do
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

shared_examples_for "EventLoop#manually_resume!" do
  before { loop.concurrent_proc do
    loop.wait 0.0001
    to_be_resumed.manually_resume! *result
  end.call_detached }

  context "when given no result" do
    let(:result) { [] }
    it { is_expected.to eq nil }
  end

  context "when given a result" do
    let(:result) { :result }
    it { is_expected.to eq :result }
  end
end

shared_examples_for "EventLoop#wait" do
  describe "waiting for given seconds" do
    let(:seconds) { 0.01 }

    let(:wait_proc) { proc do
      loop.wait(seconds)
      Time.now.to_f
    end }

    let!(:start_time) { Time.now.to_f }

    context "when originating inside a concurrent proc" do
      subject { loop.concurrent_proc(&wait_proc).call }
      it { is_expected.to be_within(0.2*seconds).of(start_time+seconds) }
    end

    context "when originating outside a concurrent proc" do
      subject { wait_proc.call }
      it { is_expected.to be_within(0.2*seconds).of(start_time+seconds) }
    end
  end

  describe "evaluating/cancelling the concurrent evaluation while it is waiting" do
    subject { evaluation.await_result }

    let(:wait_time) { 0.0001 }
    let!(:evaluation) { loop.concurrent_proc{ loop.wait wait_time; :completed }.call_detached }

    before { loop.concurrent_proc do
      # cancel the concurrent evaluation right away
      evaluation.conclude_with :intercepted

      # Wait after the timer would have been triggered to make sure the
      # concurrent evaluation is not resumed then (i.e. watching the timeout
      # is properly cancelled)
      loop.wait wait_time
    end.call }

    it { is_expected.to be :intercepted }
  end
end

shared_examples_for "EventLoop#await_readable" do
  it_behaves_like "awaiting the result of a deferred evaluation" do
    let(:wait_proc) { proc do
      loop.await_readable(reader, wait_options)
    end }

    let(:evaluation_time) { 0.001 }
    let(:result) { true }

    before { loop.concurrent_proc do
      loop.wait evaluation_time
      writer.write result
      writer.close
    end.call_detached }
  end
end

shared_examples_for "EventLoop#await_writable" do
  it_behaves_like "awaiting the result of a deferred evaluation" do
    let(:wait_proc) { proc do
      loop.await_writable(writer, wait_options)
    end }

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