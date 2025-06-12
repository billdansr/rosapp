import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rosapp/models/category.dart';
import 'package:rosapp/models/product.dart';
import 'package:rosapp/screens/product_form_screen.dart';
import 'package:rosapp/services/product_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  List<Category> _productCategories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadProductCategories();
  }

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
      await ProductService().deleteProduct(widget.product.id!);
      if (context.mounted) {
        Navigator.pop(context, true); // Back to list, signal refresh
      }
    }
  }

  Future<void> _loadProductCategories() async {
    if (widget.product.id == null) {
      setState(() => _isLoadingCategories = false);
      return;
    }
    try {
      final allCategories = await ProductService().getAllCategories();
      final assignedCategoryIds = await ProductService().getProductCategories(widget.product.id!);
      if (!mounted) return;
      setState(() {
        _productCategories = allCategories.where((cat) => assignedCategoryIds.contains(cat.id)).toList();
        _isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCategories = false);
      debugPrint('Error loading product categories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
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
                _buildDetailRow(context, Icons.qr_code_scanner, 'SKU (Kode Barang)', widget.product.sku),
                const Divider(),
                _buildDetailRow(context, Icons.description, 'Deskripsi', (widget.product.description != null && widget.product.description!.isNotEmpty) ? widget.product.description! : '-'),
                const Divider(),
                _buildDetailRow(context, Icons.price_change, 'Harga Satuan (Harga Jual)', currency.format(widget.product.unitPrice)),
                const Divider(),
                _buildDetailRow(context, Icons.inventory_2, 'Qty (Jumlah Stok)', '${widget.product.quantity} pcs'),
                const Divider(),
                _buildCategoryRow(context),
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
                            builder: (_) => ProductFormScreen(product: widget.product),
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

  Widget _buildCategoryRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.category_outlined, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kategori Produk',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 4),
                _isLoadingCategories
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : _productCategories.isEmpty
                        ? Text(
                            '-',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          )
                        : Wrap(
                            spacing: 6.0,
                            runSpacing: 4.0,
                            children: _productCategories.map((cat) => Chip(label: Text(cat.name, style: const TextStyle(fontSize: 13)), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), visualDensity: VisualDensity.compact)).toList(),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}