class IOEventLoop
  class RunQueue
    class CartPool
      def initialize
        @index = {}
        @carts = []
      end

      def take_and_load_with(fiber, time, result)
        cart = (@carts.pop or Cart.new(@carts, @index))
        @index.store fiber.hash, cart
        cart.fiber = fiber
        cart.time = time
        cart.result = result
        cart.loaded = true
        cart
      end

      def unload_by_fiber(fiber)
        if cart = @index[fiber.hash]
          cart.loaded = false
        end
      end
    end
  end
end