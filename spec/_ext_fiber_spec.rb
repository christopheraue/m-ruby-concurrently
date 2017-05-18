describe Fiber do
  let(:loop) { Concurrently::EventLoop.current }

  describe "#manually_resume!" do
    subject { fiber.resume }
    def call(*args)
      fiber.manually_resume! *args
    end
    let!(:fiber) { Fiber.new{ loop.await_manual_resume! } }

    it_behaves_like "EventLoop#manually_resume!"
  end
end