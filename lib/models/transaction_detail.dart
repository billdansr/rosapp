// lib/models/transaction_detail.dart
class TransactionDetail {
  final int id;
  final DateTime date; // Diubah dari transactionTime
  final double totalPrice; // Diubah dari totalAmount
  // Anda bisa menambahkan daftar item jika ingin menampilkan detail item per transaksi

  TransactionDetail({
    required this.id,
    required this.date,
    required this.totalPrice,
  });

  factory TransactionDetail.fromMap(Map<String, dynamic> map) {
    return TransactionDetail(
      id: map['id'] as int,
      date: DateTime.parse(map['date'] as String), // Diubah dari transaction_time
      totalPrice: map['total_price'] as double, // Diubah dari total_amount
    );
  }
}
