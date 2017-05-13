class IOEventLoop
  class RunQueue
    class CartPool
      def initialize
        @index = {}
        @carts = []
      end

      def take_and_load_with(fiber, time, result)
        cart = (@carts.pop or Cart.new(@carts, @index))
        cart.load(fiber, time, result)
        cart
      end

      def unload_by_fiber(fiber)
        if cart = @index[fiber]
          cart.unload
        end
      end
    end
  end
end