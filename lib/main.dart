import 'package:flutter/material.dart';
import 'screens/sales_report_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  // Ensure Flutter bindings are initialized if you use await before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for sqflite on desktop (and other platforms if using FFI)
  sqfliteFfiInit(); // Initialize sqflite with FFI support
  databaseFactory = databaseFactoryFfi; // Use FFI database factory

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RosApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: SalesReportScreen(),
    );
  }
}
