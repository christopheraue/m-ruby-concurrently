describe Fiber do
  before { Concurrently::EventLoop.current.reinitialize! }

  describe "#schedule_resume!" do
    subject { fiber.resume }
    def call(*args)
      fiber.schedule_resume! *args
    end
    let!(:fiber) { Fiber.new{ await_scheduled_resume! } }

    it_behaves_like "#schedule_resume!"
  end
end