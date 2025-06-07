import 'package:rosapp/models/product.dart';
import 'package:rosapp/models/cart_item.dart';

class CartService {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  factory CartService() {
    return _instance;
  }
  CartService._internal();

  final List<CartItem> _cartItems = [];

  List<CartItem> getCartItems() {
    return List.from(
      _cartItems,
    ); // Return a copy to prevent direct modification from outside
  }

  void addToCart(Product product, {int quantity = 1}) {
    final existingIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex != -1) {
      _cartItems[existingIndex].quantityInCart += quantity;
    } else {
      _cartItems.add(CartItem(product: product, quantityInCart: quantity));
    }
  }

  void incrementQuantity(CartItem item) {
    // Ensure we're modifying the item in our list
    final cartItem = _cartItems.firstWhere(
      (ci) => ci.product.id == item.product.id,
      orElse: () => item,
    );
    cartItem.quantityInCart++;
  }

  void decrementQuantity(CartItem item) {
    final cartItem = _cartItems.firstWhere(
      (ci) => ci.product.id == item.product.id,
      orElse: () => item,
    );
    if (cartItem.quantityInCart > 1) {
      cartItem.quantityInCart--;
    } else {
      _cartItems.removeWhere((ci) => ci.product.id == item.product.id);
    }
  }

  void clearCart() {
    _cartItems.clear();
  }

  double calculateTotal() {
    return _cartItems.fold(0, (sum, item) => sum + item.subtotal);
  }
}
