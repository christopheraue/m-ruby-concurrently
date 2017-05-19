describe Fiber do
  before { Concurrently::EventLoop.current.reinitialize! }

  describe "#manually_resume!" do
    subject { fiber.resume }
    def call(*args)
      fiber.manually_resume! *args
    end
    let!(:fiber) { Fiber.new{ await_manual_resume! } }

    it_behaves_like "#manually_resume!"
  end
end