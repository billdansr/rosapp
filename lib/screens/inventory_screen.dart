import 'package:flutter/material.dart';
import 'package:rosapp/models/category.dart';
import 'package:rosapp/models/cart_item.dart'; // Import CartItem model
import 'package:rosapp/models/product.dart';
import 'package:rosapp/screens/product_detail_screen.dart';
import 'package:rosapp/screens/product_form_screen.dart';
import 'package:rosapp/services/product_service.dart';
import 'package:rosapp/services/cart_service.dart'; // Import CartService
import 'package:rosapp/widgets/app_drawer.dart';
import 'package:rosapp/main.dart'; // Import MyApp for route names
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart'; // Import audioplayers

class InventarisScreen extends StatefulWidget {
  const InventarisScreen({super.key});

  @override
  State<InventarisScreen> createState() => _InventarisScreenState();
}

class _InventarisScreenState extends State<InventarisScreen> {
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  final CartService _cartService = CartService(); // Instantiate CartService
  final AudioPlayer _audioPlayer = AudioPlayer(); // Initialize AudioPlayer
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  List<Product> _productsForSelectedCategory = []; // Used when a category is selected
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<Category> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCategoriesAndInitialFilter();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose(); // Dispose the audio player
    super.dispose();
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  Future<void> _loadCategoriesAndInitialFilter() async {
    final categories = await ProductService().getAllCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _loadProducts() async {
    try {
      final products = await ProductService().getAllProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        // _filteredProducts = products; // Initial state handled by _applyFilters
        _isLoading = false;
        _applyFilters(); // Apply filters after products are loaded
      });
    } catch (e) {
      if (mounted) {
        debugPrint('Error fetching products: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    List<Product> sourceList;

    if (_selectedCategoryId == null) {
      sourceList = _allProducts;
    } else {
      sourceList = _productsForSelectedCategory;
    }

    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredProducts = List.from(sourceList);
      } else {
        _filteredProducts = sourceList.where((product) {
          return product.name.toLowerCase().contains(_searchQuery) ||
              product.sku.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  void _navigateToDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    ).then((refreshed) {
      if (refreshed == true) {
        _loadProducts(); // Reload all products and re-apply filters
      }
    });
  }

  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    ).then((refreshed) {
       if (refreshed == true) {
        _loadProducts(); // Reload all products and re-apply filters
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaris'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    textInputAction: TextInputAction.search,
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau kode barang...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0)),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                _applyFilters();
                              },
                            )
                          : null,
                    ),
                    onChanged: (query) {
                      _searchQuery = query.toLowerCase();
                      _applyFilters();
                    },
                  ),
                ),
                SingleChildScrollView(
                  key: const PageStorageKey<String>('categoryChips'), // Preserve scroll position
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: _selectedCategoryId == null,
                        selectedColor: Colors.blue.withAlpha((0.2 * 255).toInt()),
                        checkmarkColor: Colors.blue,
                        labelStyle: TextStyle(color: _selectedCategoryId == null ? Colors.blue.shade700 : Colors.black87, fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.normal),
                        side: _selectedCategoryId == null ? BorderSide(color: Colors.blue.shade300) : BorderSide(color: Colors.grey.shade400),
                        onSelected: (_) {
                          setState(() {
                            _selectedCategoryId = null;
                            _productsForSelectedCategory = []; // Clear specific category products
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: _selectedCategoryId == cat.id,
                          selectedColor: Colors.blue.withAlpha((0.2 * 255).toInt()),
                          checkmarkColor: Colors.blue,
                          labelStyle: TextStyle(color: _selectedCategoryId == cat.id ? Colors.blue.shade700 : Colors.black87, fontWeight: _selectedCategoryId == cat.id ? FontWeight.bold : FontWeight.normal),
                          side: _selectedCategoryId == cat.id ? BorderSide(color: Colors.blue.shade300) : BorderSide(color: Colors.grey.shade400),
                          onSelected: (_) async {
                            setState(() {
                              _selectedCategoryId = cat.id;
                              _isLoading = true; 
                            });
                            try {
                              final products = await ProductService().getProductsByCategory(cat.id!);
                              if (!mounted) return;
                              setState(() {
                                _productsForSelectedCategory = products;
                                _applyFilters();
                                _isLoading = false;
                              });
                            } catch (e) {
                              if (!mounted) return;
                              debugPrint('Error fetching category products: $e');
                              setState(() => _isLoading = false);
                            }
                          },
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filteredProducts.isEmpty && !_isLoading // Also check !_isLoading to avoid showing "not found" during category load
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 60, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Barang tidak ditemukan',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Coba kata kunci atau filter lain.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filteredProducts.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return Card(
                              elevation: 2.0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                title: Text(
                                  product.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'SKU: ${product.sku}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Qty. ${product.quantity} pcs',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currency.format(product.unitPrice),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.add_shopping_cart),
                                      color: Theme.of(context).primaryColor,
                                      tooltip: 'Tambah ke Keranjang',
                                      onPressed: () { // Logic for adding to cart with stock validation
                                        CartItem? existingCartItem;
                                        try {
                                          existingCartItem = _cartService
                                              .getCartItems()
                                              .firstWhere((item) =>
                                                  item.product.sku ==
                                                  product.sku);
                                        } catch (e) {
                                          // Item not found in cart, existingCartItem remains null
                                        }

                                        if (existingCartItem != null) {
                                          // Produk sudah ada di keranjang, periksa apakah bisa ditambah kuantitasnya
                                          if (existingCartItem.quantityInCart >=
                                              product.quantity) { // product.quantity is stock
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Stok maks (${product.quantity}) untuk ${product.name} sudah di keranjang.')),
                                            );
                                            return;
                                          }
                                        } else {
                                          // Produk baru, periksa apakah stok tersedia
                                          if (product.quantity <= 0) { // product.quantity is stock
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Stok barang ${product.name} habis.')),
                                            );
                                            return;
                                          }
                                        }

                                        _cartService.addToCart(product);
                                        _playSound('audio/scan_success.wav'); // Play sound effect
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${product.name} ditambahkan ke keranjang.'),
                                            duration:
                                                const Duration(seconds: 2),
                                            action: SnackBarAction(
                                              label: 'LIHAT KERANJANG',
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                    context, MyApp.posRoute);
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () => _navigateToDetail(product),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddProduct,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'Tambah Produk Baru', // Added tooltip
        child: const Icon(Icons.add),
      ),
    );
  }
}
