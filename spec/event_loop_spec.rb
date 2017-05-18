describe Concurrently::EventLoop do
  subject(:instance) { Concurrently::EventLoop.new }

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
    subject(:loop) { Concurrently::EventLoop.new }

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

  describe "#await_readable" do
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

  describe "#await_writable" do
    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:wait_proc) { proc do
        loop.await_writable(writer, wait_options)
      end }

      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }

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

  describe "#await_event" do
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