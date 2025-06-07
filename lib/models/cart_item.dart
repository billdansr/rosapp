import 'package:rosapp/models/product.dart';

class CartItem {
  final Product product;
  int quantityInCart;

  CartItem({required this.product, this.quantityInCart = 1});

  double get subtotal => product.unitPrice * quantityInCart;
}
