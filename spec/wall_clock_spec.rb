describe IOEventLoop::WallClock do
  subject { described_class.new }

  describe "#now" do
    it "returns the current time offset since initialization" do
      waiting_time = 0.1
      future = subject.now+waiting_time
      sleep waiting_time
      expect(subject.now).to be_within(0.01).of(future)
    end
  end
end
