describe Kernel do
  let!(:loop) { Concurrently::EventLoop.current.reinitialize! }

  describe "#concurrently" do
    def call(*args, &block)
      concurrently(*args, &block)
    end

    it_behaves_like "EventLoop#concurrently"
  end

  describe "#concurrent_proc" do
    def call(*args, &block)
      concurrent_proc(*args, &block)
    end

    it_behaves_like "EventLoop#concurrent_proc"
  end

  describe "#wait" do
    def call(seconds)
      wait(seconds)
    end

    it_behaves_like "EventLoop#wait"
  end

  describe "#await_manual_resume!" do
    def call(options)
      await_manual_resume! options
    end

    it_behaves_like "EventLoop#await_manual_resume!"
  end
end