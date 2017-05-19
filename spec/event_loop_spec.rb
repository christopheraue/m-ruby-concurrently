describe Concurrently::EventLoop do
  let!(:loop) { Concurrently::EventLoop.current.reinitialize! }
  subject(:instance) { loop }

  describe ".current" do
    subject { described_class.current }
    it { is_expected.to be_a described_class }
    it { is_expected.to be described_class.current } # same object for different calls
  end

  describe "#reinitialize!" do
    subject(:reinitialize) { instance.reinitialize! }

    it { is_expected.to be instance }

    context "when it is waiting for a time interval" do
      before { concurrent_proc{ wait 0; @result = :waited }.call_nonblock }

      context "when reinitialized after the concurrent proc finished waiting (for control)" do
        before { wait 0 }
        before { reinitialize }
        it { expect(@result).to be :waited  }
      end

      context "when reinitialized before the concurrent proc finished waiting" do
        before { reinitialize }
        before { wait 0 }
        it { expect(@result).to be nil  }
      end
    end

    context "when it is waiting for an IO to be readable" do
      before { @r, @w = IO.pipe }
      before { concurrent_proc{ @r.await_readable; @result = :waited }.call_nonblock }

      context "when reinitialized after the concurrent proc finished waiting (for control)" do
        before { @w.write 'waiting over' }
        before { wait 0.0001 }
        before { reinitialize }
        it { expect(@result).to eq :waited  }
      end

      context "when reinitialized before the concurrent proc finished waiting" do
        before { reinitialize }
        before { @w.write 'waiting over' }
        before { wait 0.0001 }
        it { expect(@result).to be nil  }
      end
    end

    context "when it is waiting for an IO to be writable" do
      before { @r, @w = IO.pipe }
      before { @w.write ' ' * 2**16 }
      before { concurrent_proc{ @w.await_writable; @result = :waited }.call_nonblock }

      context "when reinitialized after the concurrent proc finished waiting (for control)" do
        before { @r.read 2**16 }
        before { wait 0.0001 }
        before { reinitialize }
        it { expect(@result).to eq :waited  }
      end

      context "when reinitialized before the concurrent proc finished waiting" do
        before { reinitialize }
        before { @r.read 2**16 }
        before { wait 0.0001 }
        it { expect(@result).to be nil  }
      end
    end

    context "when it is waiting for the result of a concurrent proc" do
      let!(:evaluation) { concurrent_proc{ wait 0 }.call_nonblock }
      before { concurrent_proc{ evaluation.await_result; @result = :waited }.call_nonblock }

      context "when reinitialized after the concurrent proc finished waiting (for control)" do
        before { wait 0.0001 }
        before { reinitialize }
        it { expect(@result).to eq :waited  }
      end

      context "when reinitialized before the concurrent proc finished waiting" do
        before { reinitialize }
        before { wait 0.0001 }
        it { expect(@result).to be nil  }
      end
    end
  end

  describe "#lifetime" do
    subject { instance.lifetime }
    let!(:creation_time) { instance; Time.now.to_f }
    before { wait 0.001 }
    it { is_expected.to be_within(0.0001).of(Time.now.to_f - creation_time) }
  end

  describe "#await_manual_resume!" do
    def call(options)
      instance.await_manual_resume! options
    end

    it_behaves_like "EventLoop#await_manual_resume!"
  end

  describe "#await_event" do
    it_behaves_like "awaiting the result of a deferred evaluation" do
      let(:wait_proc) { proc{ loop.await_event(object, :event, wait_options) } }

      let(:object) { Object.new.extend CallbacksAttachable }

      let!(:resume_proc) { concurrent_proc do
        wait evaluation_time
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