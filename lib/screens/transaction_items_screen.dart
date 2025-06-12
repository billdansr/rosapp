// c:\Development\projects\rosapp\lib\screens\transaction_items_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rosapp/models/transaction_detail.dart';
import 'package:rosapp/models/transaction_item_detail.dart' as ti_detail;
import 'package:rosapp/services/product_service.dart';

class TransactionItemsScreen extends StatefulWidget {
  final TransactionDetail transactionHeader;

  const TransactionItemsScreen({
    super.key,
    required this.transactionHeader,
  });

  @override
  State<TransactionItemsScreen> createState() => _TransactionItemsScreenState();
}

class _TransactionItemsScreenState extends State<TransactionItemsScreen> {
  final ProductService _productService = ProductService();
  List<ti_detail.TransactionItemDetail> _items = [];
  bool _isLoading = true;
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  final dateTimeFormatter = DateFormat('dd MMM yyyy, HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _loadTransactionItems();
  }

  Future<void> _loadTransactionItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _productService
          .getTransactionItems(widget.transactionHeader.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat item transaksi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Transaksi #${widget.transactionHeader.id}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID Transaksi: ${widget.transactionHeader.id}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tanggal: ${dateTimeFormatter.format(widget.transactionHeader.date)}',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Transaksi:',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                currencyFormatter
                                    .format(widget.transactionHeader.totalPrice),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Item Dibeli:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Text('Tidak ada item untuk transaksi ini.'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                  '${item.quantity} x ${currencyFormatter.format(item.priceAtSale)}'),
                              trailing: Text(
                                currencyFormatter.format(item.subtotal),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
