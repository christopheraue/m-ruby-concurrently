class IOEventLoop
  class Fiber < ::Fiber; end

  class RescuedFiber
    def initialize(loop, &block)
      @fiber = Fiber.new do
        begin
          block.call
        rescue Exception => e
          loop.trigger :error, e
        end
      end
    end

    def resume
      @fiber.resume
    end
  end
end