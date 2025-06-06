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
    final categories = await ProductService().getAllCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  void _showCategoryDialog({Category? category}) {
    final controller = TextEditingController(text: category?.name ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(category == null ? 'Tambah Kategori' : 'Edit Kategori'),
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
              if (name.isEmpty) return;
              if (category == null) {
                await ProductService().addCategory(Category(name: name));
              } else {
                await ProductService().updateCategory(Category(id: category.id, name: name));
              }
              if (!mounted) return;
              Navigator.pop(context);
              _loadCategories();
            },
            child: const Text('Simpan'),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirm == true) {
      await ProductService().deleteCategory(category.id!);
      _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (_, index) {
                final category = _categories[index];
                return ListTile(
                  title: Text(category.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showCategoryDialog(category: category)),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteCategory(category)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
