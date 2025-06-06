import 'package:flutter/material.dart';
import 'package:rosapp/screens/category_screen.dart';
import 'package:rosapp/screens/inventaris_screen.dart';
import 'package:rosapp/screens/pos_screen.dart';
import 'package:rosapp/screens/sales_report_screen.dart';
import 'package:rosapp/screens/record_purchase_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Container(
            height: 100.0, // Adjust height as needed
            padding: const EdgeInsets.fromLTRB(16.0, 40.0, 16.0, 8.0), // Adjust padding (especially top)
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: const Text(
              'RosApp',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Laporan Penjualan'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SalesReportScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('Kasir'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (context) => const PosScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Inventaris'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigate to InventarisScreen, replacing the current screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const InventarisScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Kategori Barang'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CategoryScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_shopping_cart), // Atau Icons.inventory_outlined
            title: const Text('Catat Pembelian Stok'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const RecordPurchaseScreen()));
            },
          ),
        ],
      ),
    );
  }
}
