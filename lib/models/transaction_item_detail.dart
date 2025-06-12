// lib/models/transaction_item_detail.dart
class TransactionItemDetail {
  final String productName;
  final int quantity;
  final double priceAtSale;
  final double subtotal;

  TransactionItemDetail({
    required this.productName,
    required this.quantity,
    required this.priceAtSale,
    required this.subtotal,
  });

  factory TransactionItemDetail.fromMap(Map<String, dynamic> map) {
    return TransactionItemDetail(
      productName: map['product_name'] as String? ?? 'Produk Tidak Ditemukan',
      quantity: map['quantity'] as int? ?? 0,
      priceAtSale: (map['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['quantity'] as num? ?? 0).toDouble() * (map['price'] as num? ?? 0).toDouble(),
    );
  }
}
