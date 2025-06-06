// lib/models/purchase.dart
class Purchase {
  final int? id;
  final int productId;
  final int quantityPurchased;
  final double purchasePricePerUnit;
  final double totalCost;
  final DateTime purchaseDate;
  final String? supplierName;

  Purchase({
    this.id,
    required this.productId,
    required this.quantityPurchased,
    required this.purchasePricePerUnit,
    required this.purchaseDate,
    this.supplierName,
  }) : totalCost = quantityPurchased * purchasePricePerUnit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity_purchased': quantityPurchased,
      'purchase_price_per_unit': purchasePricePerUnit,
      'total_cost': totalCost,
      'purchase_date': purchaseDate.toIso8601String(),
      'supplier_name': supplierName,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      quantityPurchased: map['quantity_purchased'] as int,
      purchasePricePerUnit: map['purchase_price_per_unit'] as double,
      // totalCost dihitung, jadi tidak perlu diambil dari map kecuali Anda menyimpannya secara eksplisit
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      supplierName: map['supplier_name'] as String?,
    );
  }
}
