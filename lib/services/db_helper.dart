import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Menggunakan sqflite_common_ffi
import 'package:path/path.dart';

class DBHelper {
  static Database? _database;
  static const String dbName = 'rosapp.db';
      // NAIKKAN VERSI DATABASE untuk perubahan skema transaksi
      static const int dbVersion = 5; // Sebelumnya 4

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    sqfliteFfiInit(); // Inisialisasi FFI
    var databaseFactory = databaseFactoryFfi;
    String path = join(await databaseFactory.getDatabasesPath(), dbName);
    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onCreate: _createDb,
        onUpgrade: _onUpgrade, // Tambahkan onUpgrade untuk migrasi
      ),
    );
  }

  static Future<void> _createDb(Database db, int version) async {
    // Perintah CREATE TABLE yang sudah ada
    await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            unit_price REAL NOT NULL,
            quantity INTEGER NOT NULL,
            sku TEXT UNIQUE NOT NULL,
            updated_at TEXT 
          )
        ''');
    await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                name TEXT NOT NULL UNIQUE
          )
        ''');
    await db.execute('''
          CREATE TABLE product_categories (
            product_id INTEGER NOT NULL,
            category_id INTEGER NOT NULL,
            PRIMARY KEY (product_id, category_id),
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
          )
        ''');
    // Tambahkan tabel baru di sini saat pertama kali DB dibuat
    await _createTransactionTables(db);
    await _createPurchasesTable(db); // Tambahkan ini
  }

  // Metode untuk menangani upgrade database
  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTransactionTables(db);
    }
    if (oldVersion < 3) { // Tambahkan blok ini untuk versi 3
      await _createPurchasesTable(db);
    }
    if (oldVersion < 4) {
      await db.execute("DROP TABLE IF EXISTS categories");
      await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            name TEXT NOT NULL UNIQUE
          )
        ''');
    }
    if (oldVersion < 5) { // Perubahan skema transaksi
      await _dropAndRecreateTransactionTables(db);
    }
  }
  // Helper method untuk membuat tabel transaksi agar tidak duplikasi kode
  static Future<void> _createTransactionTables(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_price REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT 
      )
    ''');
  }

  // Metode baru untuk menghapus dan membuat ulang tabel transaksi sesuai skema baru
  static Future<void> _dropAndRecreateTransactionTables(Database db) async {
    await db.execute("DROP TABLE IF EXISTS transaction_items");
    await db.execute("DROP TABLE IF EXISTS transactions");

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_price REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT 
      )
    ''');
  }

  // Helper method untuk membuat tabel pembelian
  static Future<void> _createPurchasesTable(Database db) async {
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity_purchased INTEGER NOT NULL,
        purchase_price_per_unit REAL NOT NULL,
        total_cost REAL NOT NULL, 
        purchase_date TEXT NOT NULL,
        supplier_name TEXT,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      )
    ''');
  }
}
