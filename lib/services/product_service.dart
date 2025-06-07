import 'package:intl/intl.dart';
import 'package:rosapp/models/category.dart';
import 'package:rosapp/models/purchase_detail.dart';
import 'package:rosapp/screens/pos_screen.dart'; // Untuk CartItem
import 'package:rosapp/models/product.dart';
import 'package:rosapp/models/transaction_detail.dart'; // Asumsikan model ini ada
import 'package:rosapp/models/purchase.dart'; // Import the Purchase model
import 'package:rosapp/services/db_helper.dart';

class ProductService {
  Future<int> insertProduct(Product product) async {
    final db = await DBHelper.database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await DBHelper.database;
    final maps = await db.query('products', orderBy: 'updated_at DESC');
    return maps.map((map) => Product.fromMap(map)).toList();
  }
  
  Future<Product?> getProductBySku(String sku) async {
    final db = await DBHelper.database;
    final maps = await db.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku],
    );
    if (maps.isNotEmpty) return Product.fromMap(maps.first);
    return null;
  }

  Future<int> updateProduct(Product product) async {
    final db = await DBHelper.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await DBHelper.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getProductsByCategory(int categoryId) async {
    final db = await DBHelper.database;
    final result = await db.rawQuery('''
      SELECT p.*
      FROM products p
      JOIN product_categories pc ON p.id = pc.product_id
      WHERE pc.category_id = ?
    ''', [categoryId]);

    return result.map((row) => Product.fromMap(row)).toList();
  }

    Future<List<Product>> getProductsByName(String name) async {
    final db = await DBHelper.database;
    final maps = await db.query(
      'products',
      where: 'name LIKE ?',
      whereArgs: ['%$name%'], // Use LIKE for partial matching
      orderBy: 'name ASC',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<Category>> getAllCategories() async {
    final db = await DBHelper.database;
    final result = await db.query('categories');
    return result.map((map) => Category.fromMap(map)).toList();
  }

  Future<void> assignCategoriesToProduct(int productId, List<int> categoryIds) async {
    final db = await DBHelper.database;

    // Remove old assignments
    await db.delete('product_categories', where: 'product_id = ?', whereArgs: [productId]);

    // Insert new ones
    for (final categoryId in categoryIds) {
      await db.insert('product_categories', {
        'product_id': productId,
        'category_id': categoryId,
      });
    }
  }

  Future<List<int>> getProductCategories(int productId) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'product_categories',
      columns: ['category_id'],
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return result.map((map) => map['category_id'] as int).toList();
  }

  Future<void> addCategory(Category category) async {
    final db = await DBHelper.database;
    // Periksa apakah nama kategori sudah ada
    final existing = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [category.name],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('Kategori dengan nama "${category.name}" sudah ada.');
    }
    await db.insert('categories', category.toMap());
  }

  Future<void> updateCategory(Category category) async {
    final db = await DBHelper.database;
    // Periksa apakah nama kategori baru sudah digunakan oleh kategori lain
    if (category.id != null) {
      final existing = await db.query(
        'categories',
        where: 'name = ? AND id != ?',
        whereArgs: [category.name, category.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw Exception('Kategori lain dengan nama "${category.name}" sudah ada.');
      }
    }
    await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<void> deleteCategory(int id) async {
    final db = await DBHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> recordTransaction({
    required double totalPrice, // Diubah dari totalAmount
    required DateTime date, // Diubah dari transactionTime
    required List<CartItem> items,
  }) async {
    final db = await DBHelper.database;
    return await db.transaction((txn) async {
      // 1. Insert into transactions table
      int transactionId = await txn.insert('transactions', {
        'date': date.toIso8601String(), // Diubah
        'total_price': totalPrice, // Diubah
      });

      // 2. Insert into transaction_items table
      for (var cartItem in items) {
        await txn.insert('transaction_items', {
          'transaction_id': transactionId,
          'product_id': cartItem.product.id,
          'quantity': cartItem.quantityInCart, // Diubah dari quantity_sold
          'price': cartItem.product.unitPrice, // Diubah dari unit_price_at_sale
          // product_name dan subtotal dihapus sesuai skema baru
        });

        // 3. Update product stock
        // int productId = cartItem.product.id!; // productId sudah ada dari cartItem
        // int quantitySold = cartItem.quantityInCart;

        // Get current quantity
        final List<Map<String, dynamic>> currentProduct = await txn.query('products', columns: ['quantity'], where: 'id = ?', whereArgs: [cartItem.product.id]);
        if (currentProduct.isNotEmpty) {
          int newQuantity = currentProduct.first['quantity'] - cartItem.quantityInCart;
          await txn.update('products', {'quantity': newQuantity, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [cartItem.product.id]);
        }
      }
      return transactionId;
    });
  }

  // --- Sales Report Methods ---

  Future<double> getTotalSalesAllTime() async {
    final db = await DBHelper.database;
    final result = await db.rawQuery('SELECT SUM(total_price) as total FROM transactions'); // Diubah
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<double> getTotalSalesForPeriod(DateTime startDate, DateTime endDate) async {
    final db = await DBHelper.database;
    final startDateSql = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateSql = DateFormat('yyyy-MM-dd').format(endDate);

    final result = await db.rawQuery(
      'SELECT SUM(total_price) as total FROM transactions WHERE DATE(date) BETWEEN ? AND ?',
      [startDateSql, endDateSql],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }
  Future<int> getTransactionCountForPeriod(DateTime startDate, DateTime endDate) async {
    final db = await DBHelper.database;
    final startDateSql = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateSql = DateFormat('yyyy-MM-dd').format(endDate);

    final result = await db.rawQuery(
      'SELECT COUNT(id) as count FROM transactions WHERE DATE(date) BETWEEN ? AND ?',
      [startDateSql, endDateSql],
    );
    if (result.isNotEmpty && result.first['count'] != null) {
      return result.first['count'] as int;
    }
    return 0;
  }
  Future<List<TransactionDetail>> getRecentTransactions({int limit = 5}) async {
    final db = await DBHelper.database;
    final maps = await db.query(
      'transactions',
      orderBy: 'date DESC', // Diubah
      limit: limit,
    );
    return maps.map((map) => TransactionDetail.fromMap(map)).toList();
  }

  // --- Purchase (Stock In / Expense) Methods ---

  Future<void> recordPurchase(Purchase purchase) async {
    final db = await DBHelper.database;
    await db.transaction((txn) async {
      // 1. Insert into purchases table
      await txn.insert('purchases', purchase.toMap());

      // 2. Update product stock
      final List<Map<String, dynamic>> currentProduct = await txn.query(
        'products',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [purchase.productId],
      );

      if (currentProduct.isNotEmpty) {
        int currentQuantity = currentProduct.first['quantity'] as int;
        int newQuantity = currentQuantity + purchase.quantityPurchased;
        await txn.update(
          'products',
          {'quantity': newQuantity, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [purchase.productId],
        );
      }
    });
  }

  Future<double> getTotalPurchasesForPeriod(DateTime startDate, DateTime endDate) async {
    final db = await DBHelper.database;
    final startDateSql = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateSql = DateFormat('yyyy-MM-dd').format(endDate);

    // Perbaiki query untuk menghitung total biaya pembelian secara akurat
    // dengan menjumlahkan (purchasePricePerUnit * quantityPurchased)
    final result = await db.rawQuery('''
      SELECT SUM(purchase_price_per_unit * quantity_purchased) as total
      FROM purchases
      WHERE DATE(purchase_date) BETWEEN ? AND ?
    ''',
    [startDateSql, endDateSql],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }
  Future<double> getEstimatedCogsForPeriod(DateTime startDate, DateTime endDate) async {
    final db = await DBHelper.database;
    final startDateSql = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateSql = DateFormat('yyyy-MM-dd').format(endDate);

    // Ambil semua item transaksi untuk tanggal yang dipilih
    final List<Map<String, dynamic>> transactionItemsSold = await db.rawQuery('''
      SELECT ti.product_id, ti.quantity
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE DATE(t.date) BETWEEN ? AND ?
    ''', [startDateSql, endDateSql]);

    if (transactionItemsSold.isEmpty) {
      return 0.0;
    }

    double totalCogs = 0.0;

    for (var item in transactionItemsSold) {
      int productId = item['product_id'] as int;
      int quantitySold = item['quantity'] as int;

      // Ambil harga beli rata-rata untuk produk ini dari tabel purchases
      final List<Map<String, dynamic>> avgPurchasePriceResult = await db.rawQuery('''
        SELECT AVG(purchase_price_per_unit) as avg_cost
        FROM purchases
        WHERE product_id = ?
      ''', [productId]);

      double productCost = 0.0;
      if (avgPurchasePriceResult.isNotEmpty && avgPurchasePriceResult.first['avg_cost'] != null) {
        productCost = (avgPurchasePriceResult.first['avg_cost'] as num).toDouble();
      }
      totalCogs += productCost * quantitySold;
    }
    return totalCogs;
  }

  // Metode untuk data grafik: penjualan harian dalam rentang tanggal
  Future<List<Map<String, dynamic>>> getDailySalesForChart(DateTime startDate, DateTime endDate) async {
    final db = await DBHelper.database;
    final startDateSql = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateSql = DateFormat('yyyy-MM-dd').format(endDate);

    final result = await db.rawQuery('''
      SELECT 
        DATE(date) as sales_date, 
        SUM(total_price) as daily_total
      FROM transactions
      WHERE DATE(date) BETWEEN ? AND ?
      GROUP BY DATE(date)
      ORDER BY sales_date ASC
    ''', [startDateSql, endDateSql]);
    return result;
  }

  Future<List<PurchaseDetail>> getPurchasesForPeriodReport(DateTime startDate, DateTime endDate) async {
    final List<Map<String, dynamic>> maps = await DBHelper.getPurchasesWithDetailsForPeriod(startDate, endDate);
    return List.generate(maps.length, (i) {
      return PurchaseDetail.fromMap(maps[i]);
    });
  }
}
