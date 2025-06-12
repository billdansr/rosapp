import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rosapp/models/product.dart';
import 'package:rosapp/screens/product_form_screen.dart';
import 'package:rosapp/services/product_service.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  ProductDetailScreen({super.key, required this.product});

  void _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: const Text('Yakin ingin menghapus produk ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ProductService().deleteProduct(product.id!);
      if (context.mounted) {
        Navigator.pop(context, true); // Back to list, signal refresh
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(context, Icons.qr_code_scanner, 'SKU (Kode Barang)', product.sku),
                const Divider(),
                _buildDetailRow(context, Icons.description, 'Deskripsi', (product.description != null && product.description!.isNotEmpty) ? product.description! : '-'),
                const Divider(),
                _buildDetailRow(context, Icons.inventory_2, 'Jumlah Stok', '${product.quantity} pcs'),
                const Divider(),
                _buildDetailRow(context, Icons.price_change, 'Harga Satuan (Harga Jual)', currency.format(product.unitPrice)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductFormScreen(product: product),
                          ),
                        ).then((value) {
                          // If the product was updated, ProductFormScreen might return true or the updated product.
                          // For simplicity, we assume the list screen (previous screen) will reload.
                          // If ProductDetailScreen needs to reflect changes immediately without popping,
                          // a more complex state management or callback would be needed.
                          if (value == true && context.mounted) { // Assuming ProductFormScreen returns true on successful save
                            Navigator.pop(context, true); // Pop with a signal to refresh
                          } else if (context.mounted && value == null) {
                            // If nothing was returned (e.g. back button pressed on form),
                            // we might still want to pop if the intent is to refresh the previous list.
                            // However, if the detail screen was pushed from somewhere else, this might not be desired.
                            // For now, let's assume it always pops to refresh the previous list.
                            // Navigator.pop(context);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Hapus'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}