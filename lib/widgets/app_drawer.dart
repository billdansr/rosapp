import 'package:flutter/material.dart';
import 'package:rosapp/main.dart'; // Import MyApp to access route names

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

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
            selected: currentRoute == MyApp.salesReportRoute,
            selectedTileColor: Colors.blue.withAlpha((0.1 * 255).toInt()),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              if (currentRoute != MyApp.salesReportRoute) {
                Navigator.pushReplacementNamed(context, MyApp.salesReportRoute);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('Kasir'),
            selected: currentRoute == MyApp.posRoute,
            selectedTileColor: Colors.blue.withAlpha((0.1 * 255).toInt()),

            onTap: () {
              Navigator.pop(context); // Close the drawer
              if (currentRoute != MyApp.posRoute) {
                Navigator.pushReplacementNamed(context, MyApp.posRoute);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Inventaris'),
            selected: currentRoute == MyApp.inventarisRoute,
            selectedTileColor: Colors.blue.withAlpha((0.1 * 255).toInt()),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              if (currentRoute != MyApp.inventarisRoute) {
                Navigator.pushReplacementNamed(context, MyApp.inventarisRoute);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Kategori Barang'),
            selected: currentRoute == MyApp.categoryRoute,
            selectedTileColor: Colors.blue.withAlpha((0.1 * 255).toInt()),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              if (currentRoute != MyApp.categoryRoute) {
                Navigator.pushReplacementNamed(context, MyApp.categoryRoute);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_outlined),
            title: const Text('Catat Pembelian Stok'),
            selected: currentRoute == MyApp.recordPurchaseRoute,
            selectedTileColor: Colors.blue.withAlpha((0.1 * 255).toInt()),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              if (currentRoute != MyApp.recordPurchaseRoute) {
                Navigator.pushReplacementNamed(context, MyApp.recordPurchaseRoute);
              }
            },
          ),
        ],
      ),
    );
  }
}
