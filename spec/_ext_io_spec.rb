describe IO do
  let(:loop) { Concurrently::EventLoop.current }
  before { loop.reinitialize! } # in case the loop is exited due to an error

  describe "#await_readable" do
    def call(options)
      reader.await_readable options
    end

    it_behaves_like "EventLoop#await_readable"
  end

  describe "#await_writable" do
    def call(options)
      writer.await_writable options
    end

    it_behaves_like "EventLoop#await_writable"
  end
end