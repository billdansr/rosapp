import 'package:flutter/material.dart';
import 'package:rosapp/models/category.dart';
import 'package:rosapp/models/product.dart';
import 'package:rosapp/services/product_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final unitPriceController = TextEditingController();
  final quantityController = TextEditingController();
  final skuController = TextEditingController();

  List<Category> _categories = [];
  final Set<int> _selectedCategoryIds = {};


  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      nameController.text = widget.product!.name;
      descriptionController.text = widget.product!.description ?? '';
      unitPriceController.text = widget.product!.unitPrice.toStringAsFixed(0); // Remove decimals for display
      quantityController.text = widget.product!.quantity.toString();
      skuController.text = widget.product!.sku;
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load all available categories
    final allCategories = await ProductService().getAllCategories();
    if (!mounted) return;
    setState(() {
      _categories = allCategories;
    });

    // If editing a product, load its assigned categories
    if (widget.product != null && widget.product!.id != null) {
      final assignedCategoryIds = await ProductService().getProductCategories(widget.product!.id!);
      if (!mounted) return;
      setState(() {
        _selectedCategoryIds.addAll(assignedCategoryIds);
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    unitPriceController.dispose();
    quantityController.dispose();
    skuController.dispose();
    super.dispose();
  }

  void saveProduct() async {
    if (!mounted) return; // Check if the widget is still in the tree
    final currentSku = skuController.text;
    // Check for SKU duplication only if it's a new product or if the SKU has changed for an existing product
    if (widget.product == null || widget.product!.sku != currentSku) {
      final isDuplicate = await ProductService().getProductBySku(currentSku);
      if (isDuplicate != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SKU sudah digunakan. Gunakan SKU lain.')),
        );
        return;
      }
    }

    if (_formKey.currentState!.validate()) {
      // Create the product object with data from controllers
      // The ID will be null if it's a new product, or the existing ID if editing
      Product productToSave = Product(
        id: widget.product?.id,
        name: nameController.text,
        description: descriptionController.text,
        unitPrice: double.parse(unitPriceController.text),
        quantity: int.parse(quantityController.text),
        sku: skuController.text,
        updatedAt: DateTime.now(),
      );

      int productId;

      if (widget.product == null) {
        // It's a new product, insert it first to get the ID
        productId = await ProductService().insertProduct(productToSave);
      } else {
        // It's an existing product, update it
        await ProductService().updateProduct(productToSave);
        productId = productToSave.id!; // ID is already known
      }
      
      await ProductService().assignCategoriesToProduct(productId, _selectedCategoryIds.toList());

      if (!mounted) return;
      Navigator.pop(context, true); // Return true to indicate success/refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Tambah Produk' : 'Edit Produk'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(
                controller: nameController,
                labelText: 'Nama Produk',
                icon: Icons.label_outline,
                validator: (value) => value == null || value.isEmpty ? 'Nama produk wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: skuController,
                labelText: 'SKU (Kode Barang)',
                icon: Icons.qr_code_scanner,
                validator: (value) => value == null || value.isEmpty ? 'SKU wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: descriptionController,
                labelText: 'Deskripsi (Opsional)',
                icon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: unitPriceController,
                        labelText: 'Harga Satuan',
                        icon: Icons.money_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Harga wajib diisi';
                        if (double.tryParse(value) == null) return 'Format harga tidak valid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: quantityController,
                      labelText: 'Jumlah Stok',
                      icon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Jumlah wajib diisi';
                        if (int.tryParse(value) == null) return 'Format jumlah tidak valid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kategori Produk',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _categories.isEmpty
                        ? const Text('Tidak ada kategori tersedia. Tambahkan kategori terlebih dahulu.')
                        : Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategoryIds.contains(cat.id);
                              return FilterChip(
                                label: Text(cat.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedCategoryIds.add(cat.id!);
                                    } else {
                                      _selectedCategoryIds.remove(cat.id);
                                    }
                                  });
                                },
                                selectedColor: Colors.blue.withAlpha((0.2 * 255).toInt()),
                                checkmarkColor: Colors.blue,
                                side: isSelected
                                    ? BorderSide(color: Colors.blue.shade300)
                                    : BorderSide(color: Colors.grey.shade400),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.blue.shade700 : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                onPressed: saveProduct,
                label: const Text('Simpan Produk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),

        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.blue, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
    );
  }
}