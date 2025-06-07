import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rosapp/screens/sales_report_screen.dart';
import 'package:rosapp/screens/pos_screen.dart';
import 'package:rosapp/screens/inventaris_screen.dart';
import 'package:rosapp/screens/category_screen.dart';
import 'package:rosapp/screens/record_purchase_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized if you use await before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for sqflite on desktop (and other platforms if using FFI)
  sqfliteFfiInit(); // Initialize sqflite with FFI support
  databaseFactory = databaseFactoryFfi; // Use FFI database factory

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static const String salesReportRoute = '/';
  static const String posRoute = '/pos';
  static const String inventarisRoute = '/inventaris';
  static const String categoryRoute = '/category';
  static const String recordPurchaseRoute = '/record-purchase';


  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RosApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: salesReportRoute, // Set initial route
      routes: {
        salesReportRoute: (context) => const SalesReportScreen(),
        posRoute: (context) => const PosScreen(),
        inventarisRoute: (context) => const InventarisScreen(),
        categoryRoute: (context) => const CategoryScreen(),
        recordPurchaseRoute: (context) => const RecordPurchaseScreen(),
      },
    );
  }
}
