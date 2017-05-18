describe Concurrently::EventLoop do
  subject(:instance) { Concurrently::EventLoop.new }

  describe ".current" do
    subject { described_class.current }
    it { is_expected.to be_a described_class }
    it { is_expected.to be described_class.current } # same object for different calls
  end

  describe "#reinitialize!" do
    subject(:reinitialize) { instance.reinitialize! }

    it { is_expected.to be true }

    context "when it is waiting for a time interval" do
      before { instance.concurrent_proc{ instance.wait 0; @result = :waited }.call_nonblock }

      context "when reinitialized after the concurrent proc finished waiting (for control)" do
        before { instance.wait 0 }
        before { reinitialize }
        it { expect(@result).to be :waited  }
      end

      context "when reinitialized before the concurrent proc finished waiting" do
        before { reinitialize }
        before { instance.wait 0 }
        it { expect(@result).to be nil  }
      end
    end

    context "when it is waiting for an IO to be readable" do
      before { @r, @w = IO.pipe }
      before { instance.concurrent_proc{ instance.await_readable @r; @result = :waited }.call_nonblock }

      context "when reinitialized after the concurrent proc finished waiting (for control)" do
        before { @w.write 'waiting over' }
        before { instance.wait 0.0001 }
        before { reinitialize }
        it { expect(@result).to eq :waited  }
      end

      context "when reinitialized before the concurrent proc finished waiting" do
        before { reinitialize }
        before { @w.write 'waiting over' }
        before { instance.wait 0.0001 }
        it { expect(@result).to be nil  }
      end
    end

    context "when it is waiting for an IO to be writable" do
      before { @r, @w = IO.pipe }
      before { @w.write ' ' * 2**16 }
      before { instance.concurrent_proc{ instance.await_writable @w; @result = :waited }.call_nonblock }

      context "when reinitialized after the concurrent proc finished waiting (for control)" do
        before { @r.read 2**16 }
        before { instance.wait 0.0001 }
        before { reinitialize }
        it { expect(@result).to eq :waited  }
      end

      context "when reinitialized before the concurrent proc finished waiting" do
        before { reinitialize }
        before { @r.read 2**16 }
        before { instance.wait 0.0001 }
        it { expect(@result).to be nil  }
      end
    end

    context "when it is waiting for the result of a concurrent proc" do
      let!(:concurrent_proc) { instance.concurrent_proc{ instance.wait 0 }.call_nonblock }
      before { instance.concurrent_proc{ concurrent_proc.await_result; @result = :waited }.call_nonblock }

      context "when reinitialized after the concurrent proc finished waiting (for control)" do
        before { instance.wait 0.0001 }
        before { reinitialize }
        it { expect(@result).to eq :waited  }
      end

      context "when reinitialized before the concurrent proc finished waiting" do
        before { reinitialize }
        before { instance.wait 0.0001 }
        it { expect(@result).to be nil  }
      end
    end
  end

  describe "#lifetime" do
    subject { instance.lifetime }
    let!(:creation_time) { instance; Time.now.to_f }
    before { instance.wait 0.001 }
    it { is_expected.to be_within(0.0001).of(Time.now.to_f - creation_time) }
  end

  describe "#wait" do
    let(:loop) { instance }
    it_behaves_like "EventLoop#wait"

    describe "order of multiple deferred concurrent evaluations" do
      subject { evaluation.await_result }

      let!(:evaluation1) { loop.concurrent_proc{ loop.wait(seconds1); callback1.call }.call_detached }
      let!(:evaluation2) { loop.concurrent_proc{ loop.wait(seconds2); callback2.call }.call_detached }
      let!(:evaluation3) { loop.concurrent_proc{ loop.wait(seconds3); callback3.call }.call_detached }
      let(:evaluation) { loop.concurrent_proc{ loop.wait(0.0004) }.call_detached }
      let(:seconds1) { 0.0001 }
      let(:seconds2) { 0.0002 }
      let(:seconds3) { 0.0003 }
      let(:callback1) { proc{ :result1 } }
      let(:callback2) { proc{ :result2 } }
      let(:callback3) { proc{ :result3 } }

      context "when no block has been cancelled" do
        before { expect(callback1).to receive(:call).ordered.and_call_original }
        before { expect(callback2).to receive(:call).ordered.and_call_original }
        before { expect(callback3).to receive(:call).ordered.and_call_original }

        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect(evaluation2.await_result).to be :result2 }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when the first block has been cancelled" do
        before { evaluation1.cancel }

        before { expect(callback1).not_to receive(:call) }
        before { expect(callback2).to receive(:call).ordered.and_call_original }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect{ evaluation1.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect(evaluation2.await_result).to be :result2 }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when the first and second block have been cancelled" do
        before { evaluation1.cancel }
        before { evaluation2.cancel }

        before { expect(callback1).not_to receive(:call) }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect{ evaluation1.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect{ evaluation2.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when all evaluations have been cancelled" do
        before { evaluation1.cancel }
        before { evaluation2.cancel }
        before { evaluation3.cancel }

        before { expect(callback1).not_to receive(:call) }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).not_to receive(:call) }
        it { is_expected.not_to raise_error }
        after { expect{ evaluation1.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect{ evaluation2.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect{ evaluation3.await_result }.to raise_error Concurrently::Proc::CancelledError }
      end

      context "when the second block has been cancelled" do
        before { evaluation2.cancel }

        before { expect(callback1).to receive(:call).ordered.and_call_original }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect{ evaluation2.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect(evaluation3.await_result).to be :result3 }
      end

      context "when the second and last block have been cancelled" do
        before { evaluation2.cancel }
        before { evaluation3.cancel }

        before { expect(callback1).to receive(:call).ordered.and_call_original }
        before { expect(callback2).not_to receive(:call) }
        before { expect(callback3).not_to receive(:call) }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect{ evaluation2.await_result }.to raise_error Concurrently::Proc::CancelledError }
        after { expect{ evaluation3.await_result }.to raise_error Concurrently::Proc::CancelledError }
      end

      context "when all timers are triggered in one go" do
        let(:seconds1) { 0 }
        let(:seconds2) { 0 }
        let(:seconds3) { 0 }

        before { expect(callback1).to receive(:call).ordered.and_call_original }
        before { expect(callback2).to receive(:call).ordered.and_call_original }
        before { expect(callback3).to receive(:call).ordered.and_call_original }
        it { is_expected.not_to raise_error }
        after { expect(evaluation1.await_result).to be :result1 }
        after { expect(evaluation2.await_result).to be :result2 }
        after { expect(evaluation3.await_result).to be :result3 }
      end
    end

    describe "repeated execution in a fixed interval" do
      subject { evaluation.await_result }

      before { @count = 0 }
      let(:evaluation) { loop.concurrent_proc do
        while (@count += 1) < 4
          loop.wait(0.0001)
          callback.call
        end
        :result
      end.call_detached }
      let(:callback) { proc{} }

      before { expect(callback).to receive(:call).exactly(3).times }
      it { is_expected.to be :result }
    end

    describe "the execution order of concurrent procs scheduled to run during a single iteration" do
      subject { loop.wait 0; @counter += 1 }

      before { @counter = 0 }
      let!(:evaluation1) { loop.concurrent_proc{ loop.wait 0.0001; @counter += 1 }.call_nonblock }
      let!(:evaluation2) { loop.concurrent_proc{ loop.wait 0; @counter += 1 }.call_nonblock }
      let!(:evaluation3) { loop.concurrent_proc{ @counter += 1 }.call_detached }
      # let the system clock progress so the block waiting non-zero seconds becomes pending
      before { sleep 0.0001 }

      it { is_expected.to be 4 }

      # scheduled starts come first, then the waiting procs
      after { expect(evaluation1.await_result).to be 3 }
      after { expect(evaluation2.await_result).to be 2 }
      after { expect(evaluation3.await_result).to be 1 }
    end
  end

  describe "#await_manual_resume!" do
    let(:loop) { instance }
    it_behaves_like "EventLoop#await_manual_resume!"
  end

  describe "#await_readable" do
    it_behaves_like "EventLoop#await_readable" do
      let(:loop) { instance }
      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }
    end
  end

  describe "#await_writable" do
    it_behaves_like "EventLoop#await_writable" do
      let(:loop) { instance }
      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }
    end
  end

  describe "#await_event" do
    let(:loop) { instance }
    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:wait_proc) { proc{ loop.await_event(object, :event, wait_options) } }

      let(:object) { Object.new.extend CallbacksAttachable }

      before { loop.concurrent_proc do
        loop.wait evaluation_time
        object.trigger :event, result
      end.call_detached }
    end
  end

  describe "#watch_events" do
    subject { instance.watch_events(object, :event) }

    let(:object) { Object.new.extend CallbacksAttachable }

    it { is_expected.to be_a(Concurrently::EventWatcher).and having_attributes(loop: instance,
      subject: object, event: :event)}
  end
end