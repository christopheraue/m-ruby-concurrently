describe "using #await_readable in concurrent blocks" do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  let(:ready_time) { 0.0001 }

  describe "waiting indefinitely" do
    let(:concurrency) { loop.concurrently(&wait_proc) }

    before { loop.concurrently do
      loop.wait ready_time
      writer.write 'Wake up!'
      writer.close
    end }

    let(:wait_proc) { proc do
      loop.await_readable reader
      reader.read
    end }

    context "when originating inside a concurrent block" do
      subject { concurrency.result }
      it { is_expected.to eq 'Wake up!' }
    end

    context "when originating outside a concurrent block" do
      subject { wait_proc.call }
      it { is_expected.to eq 'Wake up!' }
    end

    describe "evaluating/cancelling the concurrent block while it is waiting" do
      subject { concurrency.result }

      before do # make sure the concurrent block is started before evaluating it
        concurrency
      end

      before { loop.concurrently do
        # cancel the concurrent block half way through the waiting time
        loop.wait ready_time/2
        concurrency.evaluate_to :intercepted

        # Wait after the reader is readable to make sure the concurrent block
        # is not resumed then (i.e. watching the reader is properly cancelled)
        loop.wait ready_time
      end.result }

      it { is_expected.to be :intercepted }
    end
  end

  describe "waiting with a timeout" do
    subject { concurrency.result }

    let(:wait_proc) { proc{ loop.await_readable reader, within: 5*ready_time } }
    let(:concurrency) { loop.concurrently(&wait_proc) }

    context "when readable after some time" do
      before { loop.concurrently do
        loop.wait ready_time
        writer.write 'Wake up!'
        writer.close
      end }

      it { is_expected.to be true }

      describe "evaluating/cancelling the concurrent block while it is waiting" do
        before do # make sure the concurrent block is started before evaluating it
          concurrency
        end

        before { loop.concurrently do
          # cancel the concurrent block half way through the waiting time
          loop.wait ready_time/2
          concurrency.evaluate_to :intercepted

          # Wait after the reader is readable to make sure the concurrent block
          # is not resumed then (i.e. watching the reader is properly cancelled)
          loop.wait ready_time
        end.result }

        it { is_expected.to be :intercepted }
      end
    end

    context "when not readable in time" do
      it { is_expected.to be false }

      describe "evaluating/cancelling the concurrent block while it is waiting" do
        before do # make sure the concurrent block is started before evaluating it
          concurrency
        end

        before { loop.concurrently do
          # cancel the concurrent block half way through the waiting time
          loop.wait ready_time/2
          concurrency.evaluate_to :intercepted

          # Wait after the timeout for readability would have been triggered
          # to make sure the concurrent block is not resumed then (i.e.
          # watching the timeout is properly cancelled)
          loop.wait 2*ready_time
        end.result }

        it { is_expected.to be :intercepted }
      end
    end
  end
end