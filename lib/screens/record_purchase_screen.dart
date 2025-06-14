// lib/screens/record_purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rosapp/models/product.dart';
import 'package:rosapp/models/purchase.dart';
import 'package:rosapp/services/product_service.dart';
import 'package:rosapp/widgets/app_drawer.dart';
import 'package:rosapp/screens/inventory_screen.dart';

class RecordPurchaseScreen extends StatefulWidget {
  const RecordPurchaseScreen({super.key});

  @override
  State<RecordPurchaseScreen> createState() => _RecordPurchaseScreenState();
}

class _RecordPurchaseScreenState extends State<RecordPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _supplierController = TextEditingController();
  DateTime _purchaseDate = DateTime.now();

  List<Product> _allProducts = []; // For autocomplete

  @override
  void initState() {
    super.initState();
    _loadAllProducts();
  }

  Future<void> _loadAllProducts() async {
    try {
      final products = await _productService.getAllProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat daftar barang: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _selectPurchaseDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _purchaseDate) {
      setState(() {
        _purchaseDate = picked;
      });
    }
  }

  Future<void> _submitPurchase() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih barang terlebih dahulu.')),
        );
        return;
      }

      final purchase = Purchase(
        productId: _selectedProduct!.id!,
        quantityPurchased: int.parse(_quantityController.text),
        purchasePricePerUnit: double.parse(_priceController.text),
        purchaseDate: _purchaseDate,
        supplierName: _supplierController.text.trim().isNotEmpty
            ? _supplierController.text.trim()
            : null,
      );

      try {
        await _productService.recordPurchase(purchase);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pembelian berhasil dicatat! Stok barang diperbarui.')),
          );
          Navigator.pushReplacement( // Navigate to a specific screen after success
            context,
            MaterialPageRoute(builder: (context) => const InventarisScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mencatat pembelian: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restok Barang'), // Changed to be more concise
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(), // Jika ingin drawer di layar ini juga
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // Product Autocomplete
              Autocomplete<Product>(
                displayStringForOption: (Product option) => '${option.name} (SKU: ${option.sku})',
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Product>.empty();
                  }
                  return _allProducts.where((Product product) {
                    final query = textEditingValue.text.toLowerCase();
                    return product.name.toLowerCase().contains(query) ||
                      product.sku.toLowerCase().contains(query);
                  });
                },
                onSelected: (Product selection) {
                  setState(() {
                    _selectedProduct = selection;
                  });
                  // Anda bisa mengisi field lain jika perlu, misal harga beli terakhir
                },
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  return TextFormField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Cari Barang (Nama/SKU)',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: fieldTextEditingController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                fieldTextEditingController.clear();
                                setState(() { _selectedProduct = null; });
                              },
                            )
                          : null,
                    ),
                    validator: (value) {
                      if (_selectedProduct == null && (value == null || value.isEmpty)) {
                        return 'Pilih atau cari barang';
                      }
                      if (_selectedProduct == null && value != null && value.isNotEmpty) {
                        // Jika ada teks tapi tidak ada produk terpilih (misal setelah clear)
                        // Anda bisa menambahkan validasi lebih lanjut di sini jika diperlukan
                      }
                      return null;
                    },
                  );
                },
              ),
              if (_selectedProduct != null) ...[
                const SizedBox(height: 8),
                Text('Barang Terpilih: ${_selectedProduct!.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Jumlah Stok Saat Ini: ${_selectedProduct!.quantity} pcs'),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Jumlah Dibeli (pcs)',
                  prefixIcon: const Icon(Icons.numbers),
                  border: const OutlineInputBorder(),
                  suffixIcon: _quantityController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _quantityController.clear())
                    : null,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Jumlah tidak boleh kosong';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Jumlah tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Harga Beli per Unit (Rp)',
                  prefixIcon: const Icon(Icons.money),
                  border: const OutlineInputBorder(),
                  suffixIcon: _priceController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _priceController.clear())
                    : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Harga beli tidak boleh kosong';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Harga beli tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text("Tanggal Belanja: ${DateFormat('dd MMM yyyy').format(_purchaseDate)}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectPurchaseDate(context),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4)
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _supplierController,
                decoration: InputDecoration(
                  labelText: 'Nama Supplier (Opsional)',
                  prefixIcon: const Icon(Icons.store),
                  border: const OutlineInputBorder(),
                   suffixIcon: _supplierController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _supplierController.clear())
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Simpan Pembelian'),
                onPressed: _submitPurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}