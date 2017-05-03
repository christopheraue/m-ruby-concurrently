describe IOEventLoop do
  subject(:instance) { IOEventLoop.new }

  describe "#start" do
    subject { instance.start }

    before { instance.once{ expect(instance).to be_running } }
    after { expect(instance).not_to be_running }

    context "when it has no timers and nothing to watch" do
      it { is_expected.to be nil }
    end

    context "when it has nothing to watch but a timer to wait for" do
      before { instance.timers.after(0.01, &callback) }
      let(:callback) { proc{} }
      before { expect(callback).to receive(:call) }

      it { is_expected.to be nil }
    end

    context "when it has an IO object waiting for a single event" do
      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }

      context "when its waiting to be readable" do
        before { instance.timers.after(0.01) { writer.write 'Wake up!'; writer.close } }
        before { instance.await_readable(reader) }

        it { is_expected.to be nil }
        after { expect(reader.read).to eq 'Wake up!' }
      end

      context "when its waiting to be writable" do
        before { instance.await_writable(writer) }

        it { is_expected.to be nil }

        after do
          writer.write 'Hello!'; writer.close
          expect(reader.read).to eq 'Hello!'
        end
      end
    end
  end

  describe "an iteration causing an error" do
    subject { instance.start }

    before { instance.once{ raise 'evil error' } }

    before { expect(instance).to receive(:trigger).with(:error,
      (be_a(RuntimeError).and have_attributes message: 'evil error')).and_call_original }

    context "when the loop should stop and raise the error (the default)" do
      it { is_expected.to raise_error 'evil error' }
    end

    context "when the loop should forgive the error" do
      before { instance.forgive_iteration_errors! }
      it { is_expected.to be nil }
    end
  end

  describe "#await, #awaits? and #resume" do
    context "when waiting originates from the root fiber" do
      before { instance.once{ instance.resume(:request, :result) } }
      it { expect(instance.await(:request)).to be :result }
    end

    context "when waiting originates from a fiber" do
      # The loop has to be started first to enter a fiber
      subject { instance.start }

      before { instance.once{ @result = instance.await(:request) } }
      before { instance.once{ instance.await(:another_request) } }
      before { instance.once{ instance.resume(:request, :result) } }

      it { is_expected.to be nil }
      after { expect(@result).to be :result }
      after { expect(instance.awaits? :request).to be false }
      after { expect(instance.awaits? :another_request).to be true }
    end

    context "when resuming a fiber with an unknown id" do
      subject { instance.resume(:unknown, :result) }
      it { is_expected.to raise_error IOEventLoop::UnknownWaitingIdError, "unknown waiting id :unknown" }
    end

    context "when resuming a fiber raises an error" do
      subject { instance.start }

      # e.g. resuming the fiber raises a FiberError
      before { instance.once do
        allow(Fiber.current).to receive(:resume).and_raise FiberError, 'resume error'
        instance.await(:request)
      end }
      before { instance.once{ instance.resume(:request, :result) } }

      it { is_expected.to raise_error IOEventLoop::CancelledError, 'resume error' }
    end

    context "when #await is given a timeout" do
      subject { instance.await(:id, within: 0.02, timeout_result: timeout_result) }

      let(:timeout_result) { :timeout_result }

      context "when the result arrives in time" do
        before { instance.timers.after(0.01) { instance.resume(:id, :result) } }
        it { is_expected.to be :result }
      end

      context "when evaluation of result is too slow" do
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

  describe "#cancel" do
    context "when cancelling the root fiber" do
      subject { instance.await(:request) }
      
      before { instance.once{ instance.cancel(:request, *reason) } }
      let(:reason) { nil }
      it { is_expected.to raise_error IOEventLoop::CancelledError, "waiting for id :request cancelled" }

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }
        it { is_expected.to raise_error IOEventLoop::CancelledError, "cancel reason" }
      end
    end

    context "when cancelling an iteration fiber" do
      # The loop has to be started first to enter a fiber
      subject { instance.start }

      before { instance.once do
        begin
          instance.await(:request)
        rescue IOEventLoop::CancelledError => e
          @result = e
        end
      end }
      before { instance.once{ @cancel_result = instance.cancel(:request, *reason) } }
      let(:reason) { nil }

      context "when giving no explicit reason" do
        it { is_expected.to be nil }
        after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
          message: "waiting for id :request cancelled") }
        after { expect(@cancel_result).to be :cancelled }
      end

      context "when giving a reason" do
        let(:reason) { 'cancel reason' }

        it { is_expected.to be nil }
        after { expect(@result).to be_a(IOEventLoop::CancelledError).and having_attributes(
          message: "cancel reason") }
        after { expect(@cancel_result).to be :cancelled }
      end
    end

    context "when cancelling a fiber with an unknown id" do
      subject { instance.cancel(:unknown) }
      it { is_expected.to raise_error IOEventLoop::UnknownWaitingIdError, "unknown waiting id :unknown" }
    end
  end

  describe "#once" do
    subject { instance.start }

    context "when the once block executes no request of its own" do
      before { instance.once{ @once_ran1 = 1 } }
      before { instance.once{ @once_ran2 = 2 } }

      it { is_expected.to be nil }
      after { expect(@once_ran1).to be 1 }
      after { expect(@once_ran2).to be 2 }
    end

    context "when the once block itself waits for a request" do
      before { instance.once{ @once_result = instance.await(:request) } }
      before { instance.once{ :do_nothing } }
      before { instance.once{ instance.resume(:request, :result) } }

      it { is_expected.to be nil }
      after { expect(@once_result).to be :result }
    end
  end

  describe "#attach_reader and #detach_reader" do
    subject { instance.start }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    context "when watching readability" do
      before { instance.attach_reader(reader, &callback1) }
      let(:callback1) { proc{ instance.detach_reader(reader) } }

      # make the reader readable
      before { instance.timers.after(0.01) { writer.write 'Message!' } }

      before { expect(callback1).to receive(:call).and_call_original }
      it { is_expected.to be nil }
    end
  end

  describe "#attach_writer and #detach_writer" do
    subject { instance.start }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    context "when watching writability" do
      before { instance.attach_writer(writer, &callback1) }
      let(:callback1) { proc{ instance.detach_writer(writer) } }

      before { expect(callback1).to receive(:call).and_call_original }
      it { is_expected.to be nil }
    end
  end

  describe "#await_readable" do
    subject { instance.await_readable(reader, opts) }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    shared_examples "for readability" do
      context "when readable after some time" do
        before { instance.timers.after(0.01) { writer.write 'Wake up!' } }

        before { instance.timers.after(0.005) { expect(instance.awaits_readable? reader).to be true } }
        it { is_expected.to be :readable }
        after { expect(instance.awaits_readable? reader).to be false }
      end

      context "when cancelled" do
        before { instance.timers.after(0.01) { instance.cancel_awaiting_readable reader } }

        before { instance.timers.after(0.005) { expect(instance.awaits_readable? reader).to be true } }
        it { is_expected.to be :cancelled }
        after { expect(instance.awaits_readable? reader).to be false }
      end
    end

    context "when it waits indefinitely" do
      let(:opts) { { within: nil, timeout_result: nil } }

      include_examples "for readability"

      context "when never readable" do
        # we do not have enough time to test that
      end
    end

    context "when it has a timeout" do
      let(:opts) { { within: 0.02, timeout_result: IOEventLoop::TimeoutError.new("Time's up!") } }

      include_examples "for readability"

      context "when not readable in time" do
        it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
      end
    end
  end

  describe "#await_writable" do
    subject { instance.await_writable(writer, opts) }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    # jam pipe: default pipe buffer size on linux is 65536
    before { writer.write('a' * 65536) }

    shared_examples "for writability" do
      context "when writable after some time" do
        before { instance.timers.after(0.01) { reader.read(65536) } } # clear the pipe

        before { instance.timers.after(0.005) { expect(instance.awaits_writable? writer).to be true } }
        it { is_expected.to be :writable }
        after { expect(instance.awaits_writable? writer).to be false }
      end

      context "when cancelled" do
        before { instance.timers.after(0.01) { instance.cancel_awaiting_writable writer } }

        before { instance.timers.after(0.005) { expect(instance.awaits_writable? writer).to be true } }
        it { is_expected.to be :cancelled }
        after { expect(instance.awaits_writable? writer).to be false }
      end
    end

    context "when it waits indefinitely" do
      let(:opts) { { within: nil, timeout_result: nil } }

      include_examples "for writability"

      context "when never writable" do
        # we do not have enough time to test that
      end
    end

    context "when it has a timeout" do
      let(:opts) { { within: 0.02, timeout_result: IOEventLoop::TimeoutError.new("Time's up!") } }

      include_examples "for writability"

      context "when not writable in time" do
        it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
      end
    end
  end

  describe "#watch_events" do
    subject { instance.watch_events(object, :event) }

    let(:object) { Object.new.extend CallbacksAttachable }

    it { is_expected.to be_a(IOEventLoop::EventWatcher).and having_attributes(loop: instance,
      subject: object, event: :event)}
  end
end