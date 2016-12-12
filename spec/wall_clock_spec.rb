describe AggregatedTimers::WallClock do
  describe ".now" do
    it "returns the current time offset since initialization" do
      waiting_time = 0.1
      future = described_class.now+waiting_time
      sleep waiting_time
      expect(described_class.now).to be_within(0.01).of(future)
    end
  end
end
