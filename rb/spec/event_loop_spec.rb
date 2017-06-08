describe Concurrently::EventLoop do
  subject(:instance) { Concurrently::EventLoop.current }

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
      let!(:evaluation) { concurrent_proc{ wait 0 }.call_detached }
      before { wait 0 }
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
    let!(:creation_time) { instance.reinitialize!; Time.now.to_f }
    let(:seconds) { 0.005 }
    before { wait seconds }
    it { is_expected.to be_within(0.1*seconds).of(Time.now.to_f - creation_time) }
  end
end