describe IOEventLoop::Timers do
  subject(:instance) { described_class.new }

  context "when it does not itself belong to another timers collection" do
    it { expect(instance.waiting_time).to be nil }
    it { expect(instance.triggerable).to eq [] }

    context "when it has attached timers" do
      let!(:timer1) { instance.after(seconds1, &callback1) }
      let!(:timer2) { IOEventLoop::Timer.new(seconds2, timers: instance, &callback2) }
      let!(:timer3) { instance.after(seconds3, &callback3) }
      let(:seconds1) { 0.1 }
      let(:seconds2) { 0.3 }
      let(:seconds3) { 0.2 }
      let(:callback1) { proc{} }
      let(:callback2) { proc{} }
      let(:callback3) { proc{} }

      it { expect(instance.waiting_time).to be_within(0.02).of(seconds1) }
      it { expect(instance.triggerable).to eq [] }

      context "when the next timeout has been cancelled" do
        before { timer1.cancel }
        it { expect(instance.waiting_time).to be_within(0.02).of(seconds3) }

        context "when the timeout after the next has also been cancelled" do
          before { timer3.cancel }
          it { expect(instance.waiting_time).to be_within(0.02).of(seconds2) }

          context "when the last timeout has also been cancelled" do
            before { timer2.cancel }
            it { expect(instance.waiting_time).to be nil }
          end
        end
      end

      context "when the timeout after the next has been cancelled" do
        before { timer3.cancel }
        it { expect(instance.waiting_time).to be_within(0.02).of(seconds1) }

        context "when the last timeout has also been cancelled" do
          before { timer2.cancel }
          it { expect(instance.waiting_time).to be_within(0.02).of(seconds1) }

          context "when the last timeout has also been cancelled" do
            before { timer1.cancel }
            it { expect(instance.waiting_time).to be nil }
          end
        end
      end

      context "when the timers can be triggered immediately" do
        let(:seconds1) { 0 }
        let(:seconds2) { 0 }
        let(:seconds3) { 0 }
        before { expect(instance.triggerable).to eq [timer1, timer2, timer3] }
      end
    end

    context "when it has recurring timers ready to be triggered" do
      let!(:timer) { instance.every(0, &callback) }
      let(:callback) { proc{} }

      it { expect(instance.waiting_time).to be 0 }

      context "when it is triggered" do
        before { instance.triggerable.first.trigger }
        it { expect(instance.triggerable).to eq [timer] }
      end
    end
  end
end