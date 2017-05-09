class IOEventLoop
  class RunQueue
    class CartPool
      def initialize
        @index = {}
        @carts = []
      end

      def take_and_load_with(fiber, time, result, transfer)
        cart = (@carts.pop or Cart.new(@carts, @index))
        cart.load(fiber, time, result, transfer)
        cart
      end

      def unload_by_fiber(fiber)
        if cart = @index.delete(fiber)
          cart.unload
          @carts.push cart
        end
      end
    end
  end
end