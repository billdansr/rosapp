// lib/screens/category_screen.dart
import 'package:flutter/material.dart';
import 'package:rosapp/models/category.dart';
import 'package:rosapp/services/product_service.dart';
import 'package:rosapp/widgets/app_drawer.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final categories = await ProductService().getAllCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  void _showCategoryDialog({Category? category}) {
    final controller = TextEditingController(text: category?.name ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(category == null ? 'Tambah Kategori Baru' : 'Edit Kategori'),
        content: StatefulBuilder( // Use StatefulBuilder to update suffixIcon
          builder: (BuildContext context, StateSetter setStateDialog) {
            return TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Nama Kategori',
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          setStateDialog(() {}); // Update dialog state for suffixIcon
                        },
                      )
                    : null,
              ),
              onChanged: (text) {
                // Update dialog state to show/hide suffixIcon
                setStateDialog(() {});
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama kategori tidak boleh kosong.'), backgroundColor: Colors.red),
                );
                return;
              }
              try {
                if (category == null) {
                  await ProductService().addCategory(Category(name: name));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kategori "$name" berhasil ditambahkan.'), backgroundColor: Colors.green));
                } else {
                  await ProductService().updateCategory(Category(id: category.id, name: name));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kategori "${category.name}" berhasil diperbarui menjadi "$name".'), backgroundColor: Colors.green));
                }
                if (!mounted) return;
                Navigator.pop(context);
                _loadCategories();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menyimpan kategori: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            // Disable button if name is empty by checking controller.text inside onPressed or using the StatefulBuilder's setState
            child: const Text('Simpan')
          ),
        ],
      ),
    );
  }

  void _deleteCategory(Category category) async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Yakin ingin menghapus kategori "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ProductService().deleteCategory(category.id!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kategori "${category.name}" berhasil dihapus.'), backgroundColor: Colors.green));
        _loadCategories();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus kategori: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori Barang'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Belum Ada Kategori',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tambahkan kategori baru dengan tombol +',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final category = _categories[index];
                      return Card(
                        elevation: 2.0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        child: ListTile(
                          leading: Icon(Icons.label_outline, color: Colors.blue[700]),
                          title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: Icon(Icons.edit_outlined, color: Colors.orange[700]), tooltip: "Edit Kategori", onPressed: () => _showCategoryDialog(category: category)),
                              IconButton(icon: Icon(Icons.delete_outline, color: Colors.red[700]), tooltip: "Hapus Kategori", onPressed: () => _deleteCategory(category)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'Tambah Kategori Baru',
        child: const Icon(Icons.add),
      ),
    );
  }
}
