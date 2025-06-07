class PurchaseDetail {
  final int id;
  final int productId;
  final String productName;
  final int quantityPurchased;
  final double purchasePricePerUnit;
  final double totalCost;
  final DateTime purchaseDate;
  final String? supplierName;

  PurchaseDetail({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantityPurchased,
    required this.purchasePricePerUnit,
    required this.totalCost,
    required this.purchaseDate,
    this.supplierName,
  });

  factory PurchaseDetail.fromMap(Map<String, dynamic> map) {
    return PurchaseDetail(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String? ?? 'Produk Tidak Dikenal',
      quantityPurchased: map['quantity_purchased'] as int,
      purchasePricePerUnit: map['purchase_price_per_unit'] as double,
      totalCost: map['total_cost'] as double,
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      supplierName: map['supplier_name'] as String?,
    );
  }
}
