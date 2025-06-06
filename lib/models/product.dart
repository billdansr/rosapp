class Product {
  final int? id;
  final String name;
  final String? description;
  final double unitPrice;
  final int quantity;
  final String sku;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    this.description,
    required this.unitPrice,
    required this.quantity,
    required this.sku,
    required this.updatedAt,
  });

  // Convert a Product into a Map for DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'unit_price': unitPrice,
      'quantity': quantity,
      'sku': sku,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a Product from a Map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      unitPrice: map['unit_price'] * 1.0, // Ensure unitPrice is a double
      quantity: map['quantity'],
      sku: map['sku'],
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
