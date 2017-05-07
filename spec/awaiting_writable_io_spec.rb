fdescribe "using #await_writable in concurrent blocks" do
  let(:loop) { IOEventLoop.new }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  # jam pipe: default pipe buffer size on linux is 65536
  before { writer.write('a' * 65536) }

  let(:ready_time) { 0.0001 }

  describe "waiting indefinitely" do
    let(:concurrency) { loop.concurrently(&wait_proc) }

    before { loop.concurrently do
      loop.wait ready_time
      reader.read 65536 # clears the pipe
    end }

    let(:wait_proc) { proc do
      loop.await_writable writer
      writer.write 'test'
    end }

    context "when originating inside a concurrent block" do
      subject { concurrency.result }
      it { is_expected.to be 4 }
    end

    context "when originating outside a concurrent block" do
      subject { wait_proc.call }
      it { is_expected.to be 4 }
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

    let(:wait_proc) { proc{ loop.await_writable writer, within: 5*ready_time } }
    let(:concurrency) { loop.concurrently(&wait_proc) }

    context "when writable after some time" do
      before { loop.concurrently do
        loop.wait ready_time
        reader.read 65536 # clears the pipe
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

    context "when not writable in time" do
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