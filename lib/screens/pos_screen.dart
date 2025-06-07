import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart'; // Required for DeviceOrientation
import 'package:intl/intl.dart';
import 'package:rosapp/models/product.dart';
import 'package:rosapp/models/cart_item.dart'; // Import CartItem model
import 'package:rosapp/services/product_service.dart';
import 'package:rosapp/widgets/app_drawer.dart';
import 'package:rosapp/services/cart_service.dart'; // Import CartService
import 'package:rosapp/screens/receipt_screen.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:developer';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/zxing.dart';
import 'package:zxing_lib/common.dart';
import 'dart:io'; // Diperlukan untuk File jika Anda kembali ke takePicture, tapi tidak untuk stream

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ProductService _productService = ProductService();
  CameraController? _cameraController;
  final _skuController = TextEditingController();
  final _cashTenderedController = TextEditingController();
  final CartService _cartService = CartService();

  List<CameraDescription> _cameras = [];
  List<Product> _allProducts = [];
  CameraLensDirection? _selectedCameraLensDirection;
  bool _isScanning = false;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  bool _flashEnabled = false;
  double _cashTendered = 0.0;
  double _change = 0.0;
  Timer? _scanTimerWindows;
  bool _selectionJustProcessedByAutocomplete = false;
  int _autocompleteKeyCounter = 0;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
    }

    try {
      _cameraController = CameraController(
        cameraDescription,
        ResolutionPreset.medium, // medium biasanya cukup baik untuk barcode
        enableAudio: false,
        // Try bgra8888 for Windows, as yuv420 might not be supported for streaming
        // For takePicture(), the output is usually JPEG/PNG, so this format group
        // is more about camera initialization compatibility.
        imageFormatGroup: Platform.isWindows
            ? ImageFormatGroup.bgra8888 // A common format, might be more stable for init
            : ImageFormatGroup.yuv420,  // Good for streaming on mobile
      );
      await _cameraController!.initialize().then((_) async {
        if (!mounted) return;
        if (_cameraController!.value.isInitialized) {
          try {
            await _cameraController!.setFlashMode(FlashMode.off);
          } on UnimplementedError catch (e) {
            log('setFlashMode(FlashMode.off) is not implemented on this platform: $e');
          } catch (e) {
            log('Error setting flash mode to off: $e');
          }
        }
        setState(() {
          _isCameraInitialized = true;
        });
      }).catchError((Object e) {
        log('Error initializing camera controller: $e');
        if (mounted) {
          _handleCameraInitializationError(e);
        }
      });
    } catch (e) {
      log('Unexpected error during camera initialization setup: $e');
      if (mounted) {
        _handleCameraInitializationError(e);
      }
    }
  }

  void _handleCameraInitializationError(dynamic e) {
    _cameraController = null;
    _isCameraInitialized = false;
    _isScanning = false;
    _scanTimerWindows?.cancel();
    _isDetecting = false;
    _flashEnabled = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal menginisialisasi kamera: ${e.toString()}')),
      );
      setState(() {});
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productService.getAllProducts();
      if (!mounted) return;
      setState(() => _allProducts = products);
    } catch (e) {
      log('Error loading products for POS: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat produk: $e')),
      );
    }
  }

  void _addProductToCart(Product product) {
    if (!mounted) return;

    if (_isScanning) {
      _stopScanning();
    }

    _cartService.addToCart(product);
    setState(() {
      _skuController.clear();
      _selectionJustProcessedByAutocomplete = true;
      _autocompleteKeyCounter++;
    });
  }

  Future<void> _addProductToCartBySku() async {
    final query = _skuController.text.trim();
    if (query.isEmpty) return;

    if (_isScanning) {
      _stopScanning();
    }

    try {
      Product? product = await _productService.getProductBySku(query);
      if (!mounted) return;

      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk dengan SKU "$query" tidak ditemukan')),
        );
        return;
      }
      _addProductToCart(product);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan saat mengambil produk: $e')),
      );
    }
  }

  Future<void> _scanBarcode() async {
    if (_isScanning) {
      _stopScanning();
      return;
    }

    try {
      _cameras = await availableCameras();
    } catch (e) {
      log('Error fetching available cameras: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Gagal mendapatkan daftar kamera: ${e.toString()}')),
        );
      }
      return;
    }

    if (!mounted) return;

    CameraDescription? selectedCamera;

    if (_cameras.isEmpty) {
      log('No cameras available.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada kamera yang terdeteksi.')),
      );
      return;
    } else if (_cameras.length == 1) {
      selectedCamera = _cameras.first;
    } else {
      selectedCamera = await showDialog<CameraDescription>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Pilih Kamera'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _cameras.length,
                itemBuilder: (BuildContext context, int index) {
                  final camera = _cameras[index];
                  return ListTile(
                    title: Text(camera.name),
                    leading: Icon(_getCameraLensIcon(camera.lensDirection)),
                    onTap: () {
                      Navigator.of(dialogContext).pop(camera);
                    },
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Batal'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );

      if (selectedCamera == null) {
        log('Pemilihan kamera dibatalkan.');
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _isCameraInitialized = false;
    });

    _selectedCameraLensDirection = selectedCamera.lensDirection;
    await _initializeCamera(selectedCamera);

    if (_isCameraInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      _startBarcodeDetection();
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: _buildScannerView(),
            );
          },
        ).then((_) {
          if (_isScanning) {
            _stopScanning();
          }
        });
      }
    } else {
      _stopScanning();
    }
  }

  void _startBarcodeDetection() {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      log('Camera not initialized or ready, cannot start detection');
      return;
    }

    if (!_isScanning) {
      if (mounted) setState(() => _isScanning = true);
    }

    if (Platform.isWindows) {
      log('Starting barcode detection timer for Windows (takePicture)');
      _scanTimerWindows = Timer.periodic(const Duration(milliseconds: 1000), (timer) { // Adjust interval as needed
        if (!_isScanning || _isDetecting || _cameraController == null || !_cameraController!.value.isInitialized) {
          return;
        }
        _detectBarcodeFromTakenPicture();
      });
    } else {
      log('Starting image stream for barcode detection (zxing_lib)');
      try {
        _cameraController!.startImageStream(_processCameraImage);
      } catch (e) {
        log('Error starting image stream: $e. Falling back to takePicture if applicable or stopping.');
        // Optionally, you could implement a fallback to takePicture for other platforms too if stream fails
        // For now, just log and potentially stop or show error.
        _stopScanning();
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memulai stream kamera: $e')),
          );
        }
      }
    }
  }

  void _stopScanning() {
    log('Stopping scanning');
    _scanTimerWindows?.cancel();
    _scanTimerWindows = null;

    Future<void> stopStreamFuture = Future.value();
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages &&
        !Platform.isWindows) { // Only stop stream if it was started (non-Windows)
      stopStreamFuture = _cameraController!.stopImageStream().catchError((e) {
        log('Error stopping image stream: $e');
      });
    }

    stopStreamFuture.whenComplete(() {
      if (_cameraController != null) {
        _cameraController!.dispose().then((_) {
          log('Camera controller disposed');
          _cameraController = null;
          if (mounted) {
            setState(() {
              _isScanning = false;
              _isCameraInitialized = false;
              _isDetecting = false;
              _flashEnabled = false;
            });
          }
        }).catchError((Object e) {
          log('Error disposing camera controller: $e');
          _cameraController = null;
          if (mounted) {
            setState(() {
              _isScanning = false;
              _isCameraInitialized = false;
              _isDetecting = false;
              _flashEnabled = false;
            });
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _isCameraInitialized = false;
            _isDetecting = false;
            _flashEnabled = false;
          });
        }
      }
    });
  }

  Future<void> _detectBarcodeFromTakenPicture() async {
    if (_isDetecting || !_isScanning || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    _isDetecting = true;
    String imagePath = ''; // Deklarasikan imagePath di sini agar bisa diakses di finally

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      imagePath = imageFile.path; // Tetapkan path di sini
      Uint8List imageBytes = await imageFile.readAsBytes();
      log('Windows: Picture taken, size: ${imageBytes.lengthInBytes} bytes');

      img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        log('Windows: Failed to decode image for zxing_lib.');
        _isDetecting = false;
        return;
      }

      if (_selectedCameraLensDirection == CameraLensDirection.front) {
          img.Image flippedImage = img.copyFlip(decodedImage, direction: img.FlipDirection.horizontal);
          decodedImage = flippedImage;
          log('Windows: Front camera image flipped.');
      }

      final int imageWidth = decodedImage.width;
      final int imageHeight = decodedImage.height;
      final Int32List argbInts = Int32List(imageWidth * imageHeight);
      int i = 0;
      for (final pixel in decodedImage) {
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();
        argbInts[i++] = (a << 24) | (r << 16) | (g << 8) | b;
      }

      final LuminanceSource source = RGBLuminanceSource(imageWidth, imageHeight, argbInts);
      final BinaryBitmap bitmap = BinaryBitmap(HybridBinarizer(source));
      final MultiFormatReader reader = MultiFormatReader();
      Result? zxingResult;

      try {
        zxingResult = reader.decode(bitmap);
      } on NotFoundException {
        // Barcode tidak ditemukan, ini normal
      } catch (e) {
        log('Windows (zxing_lib): Error during decoding: $e');
      }

      if (zxingResult != null && zxingResult.text.isNotEmpty && _isScanning) {
        log('Barcode detected (Windows - takePicture): ${zxingResult.text}');

        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _stopScanning();

        if (mounted) {
          setState(() {
            _skuController.text = zxingResult!.text;
          });
          await _addProductToCartBySku();
        }
      }
    } catch (e, stacktrace) {
      log('Error detecting barcode from taken picture (Windows): $e\n$stacktrace');
    } finally {
      // Hapus file gambar sementara setelah selesai diproses atau jika terjadi error
      if (imagePath.isNotEmpty) { // Pastikan imagePath sudah diisi
        try {
          final fileToDelete = File(imagePath);
          if (await fileToDelete.exists()) {
            await fileToDelete.delete();
            log('Windows: Temporary image file deleted: $imagePath');
          }
        } catch (e) {
          log('Windows: Error deleting temporary image file $imagePath: $e');
        }
      }
      _isDetecting = false;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async { // This is for non-Windows (stream)
    if (_isDetecting ||
        !_isScanning ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }
    _isDetecting = true;

    try {
      final camera = _cameraController!.description;
      final deviceOrientation = _cameraController!.value.deviceOrientation;

      final orientations = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };
      int deviceOrientationDegrees = orientations[deviceOrientation] ?? 0;
      int rotationCompensation;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation =
            (camera.sensorOrientation + deviceOrientationDegrees) % 360;
      } else {
        rotationCompensation =
            (camera.sensorOrientation - deviceOrientationDegrees + 360) % 360;
      }

      if (image.planes.isEmpty || image.planes[0].bytes.isEmpty) {
        log('Stream: Image planes are empty or Y-plane bytes are empty.');
        _isDetecting = false;
        return;
      }
      final yPlane = image.planes[0];

      if (image.width <= 0 || image.height <= 0) {
          log('Stream: Invalid image dimensions: width=${image.width}, height=${image.height}');
          _isDetecting = false;
          return;
      }

      bool reverseHorizontal =
          (camera.lensDirection == CameraLensDirection.front);

      LuminanceSource source = PlanarYUVLuminanceSource(
        yPlane.bytes,
        image.width,
        image.height,
        left: 0,
        top: 0,
        width: image.width,
        height: image.height,
        isReverseHorizontal: reverseHorizontal,
      );

      if (rotationCompensation == 90) {
        source = source.rotateCounterClockwise();
      } else if (rotationCompensation == 180) {
        source = source.rotateCounterClockwise().rotateCounterClockwise();
      } else if (rotationCompensation == 270) {
        source = source.rotateCounterClockwise()
            .rotateCounterClockwise()
            .rotateCounterClockwise();
      }

      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final MultiFormatReader reader = MultiFormatReader();
      Result? zxingResult;

      try {
        zxingResult = reader.decode(bitmap);
      } on NotFoundException {
        // Barcode tidak ditemukan, ini normal
      } catch (e) {
        log('Stream (zxing_lib): Error during decoding: $e');
      }

      if (zxingResult != null && zxingResult.text.isNotEmpty && _isScanning) {
        log('Barcode detected (zxing_lib stream): ${zxingResult.text}');

        if (_cameraController != null && _cameraController!.value.isStreamingImages && !Platform.isWindows) {
            await _cameraController!.stopImageStream().catchError((e) {
                log('Error stopping image stream after detection: $e');
            });
        }

        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _stopScanning();

        if (mounted) {
          setState(() {
            _skuController.text = zxingResult!.text;
          });
          await _addProductToCartBySku();
        }
      }
    } catch (e, stacktrace) {
      log('Error processing camera image for barcode (stream): $e\n$stacktrace');
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isScanning ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      log('Cannot toggle flash: Camera not ready or not scanning');
      return;
    }

    try {
      final newFlashMode = _flashEnabled ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);
      if (mounted) {
        setState(() {
          _flashEnabled = !_flashEnabled;
        });
      }
    } on UnimplementedError catch (e) {
      log('setFlashMode is not implemented on this platform: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Kontrol flash tidak didukung di platform ini.')),
        );
      }
    } catch (e) {
      log('Error toggling flash: $e');
    }
  }

  Widget _buildScannerView() {
    if (_isScanning && !_isCameraInitialized) {
      return Container(
        height: 300,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Menginisialisasi kamera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isScanning ||
        !_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(128),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 280,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.green,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -1,
                            left: -1,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.red, width: 4),
                                  left: BorderSide(color: Colors.red, width: 4),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.red, width: 4),
                                  right:
                                      BorderSide(color: Colors.red, width: 4),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -1,
                            left: -1,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom:
                                      BorderSide(color: Colors.red, width: 4),
                                  left: BorderSide(color: Colors.red, width: 4),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -1,
                            right: -1,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom:
                                      BorderSide(color: Colors.red, width: 4),
                                  right:
                                      BorderSide(color: Colors.red, width: 4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.8 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Posisikan barcode dalam frame dan tunggu...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.7 * 255).toInt()),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _flashEnabled ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    onPressed: _isCameraInitialized ? _toggleFlash : null,
                    tooltip: _flashEnabled ? 'Matikan flash' : 'Nyalakan flash',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.7 * 255).toInt()),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      if (Navigator.of(context, rootNavigator: true).canPop()) {
                         Navigator.of(context, rootNavigator: true).pop();
                      }
                      _stopScanning();
                    },
                    tooltip: 'Tutup scanner',
                  ),
                ),
              ],
            ),
          ),
          if (_isScanning && _isCameraInitialized)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Scanning...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _incrementQuantity(CartItem item) {
    _cartService.incrementQuantity(item);
    setState(() {});
  }

  void _decrementQuantity(CartItem item) {
    _cartService.decrementQuantity(item);
    setState(() {});
  }

  double _calculateTotal() => _cartService.calculateTotal();

  void _updateChange() {
    final total = _calculateTotal();
    final cash = double.tryParse(_cashTenderedController.text) ?? 0;
    setState(() {
      _cashTendered = cash;
      _change = cash >= total ? cash - total : 0;
    });
  }

  Future<void> _handleCheckout() async {
    if (_cartService.getCartItems().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang masih kosong')),
      );
      return;
    }

    final total = _calculateTotal();
    if (_cashTendered < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran kurang dari total')),
      );
      return;
    }

    try {
      final int transactionId = await _productService.recordTransaction(
        totalPrice: total,
        date: DateTime.now(),
        items: _cartService.getCartItems(),
      );

      if (transactionId <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mencatat transaksi.')));
        return;
      }

      final List<CartItem> itemsForReceipt =
          List.from(_cartService.getCartItems());
      final DateTime receiptTransactionTime = DateTime.now();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(
            cartItems: itemsForReceipt,
            totalPrice: total,
            cashTendered: _cashTendered,
            change: _change,
            transactionTime: receiptTransactionTime,
            transactionDbId: transactionId,
          ),
        ),
      );

      _cartService.clearCart();
      setState(() {
        _cashTenderedController.clear();
        _cashTendered = 0;
        _change = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses pembayaran: $e')),
      );
    }
  }

  void _confirmClearCart() async {
    if (_cartService.getCartItems().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang sudah kosong.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Bersihkan Keranjang'),
        content: const Text('Yakin ingin menghapus semua item dari keranjang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child:
                const Text('Bersihkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _cartService.clearCart();
      setState(() {
        _cashTenderedController.clear();
        _cashTendered = 0.0;
        _change = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _scanTimerWindows?.cancel();
    if (_isScanning || _cameraController != null) {
       _stopScanning();
    } else {
      _cameraController?.dispose();
    }
    _skuController.dispose();
    _cashTenderedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_shopping_cart_outlined),
            tooltip: 'Bersihkan Keranjang',
            onPressed: _cartService.getCartItems().isNotEmpty
                ? _confirmClearCart
                : null,
            color: _cartService.getCartItems().isNotEmpty
                ? Colors.white
                : Colors.white.withAlpha(150),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha((0.2 * 255).toInt()),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Autocomplete<Product>(
                    key: ValueKey(_autocompleteKeyCounter),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Product>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _allProducts.where((Product product) =>
                          product.sku.toLowerCase().contains(query) ||
                          product.name.toLowerCase().contains(query));
                    },
                    displayStringForOption: (Product option) =>
                        '${option.sku} - ${option.name}',
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController fieldTextEditingController,
                        FocusNode fieldFocusNode,
                        VoidCallback onFieldSubmitted) {
                      return TextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Kode Barang (SKU) / Nama',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          suffixIcon: fieldTextEditingController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    fieldTextEditingController.clear();
                                    _skuController.clear(); // Sync with _skuController
                                  },
                                )
                              : null,
                        ),
                        onChanged: (currentTextInAutocompleteField) {
                          _skuController.text = currentTextInAutocompleteField;
                          (context as Element).markNeedsBuild();
                        },
                        onSubmitted: (String submittedText) {
                          onFieldSubmitted();
                          if (_selectionJustProcessedByAutocomplete) {
                            _selectionJustProcessedByAutocomplete = false;
                            return;
                          }
                          _skuController.text = fieldTextEditingController.text;
                          _addProductToCartBySku();
                        },
                      );
                    },
                    onSelected: (Product selection) {
                      _addProductToCart(selection);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Tambah'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  onPressed: _addProductToCartBySku,
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _isScanning ? Colors.red : Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isScanning ? Icons.stop : Icons.qr_code_scanner,
                      color: Colors.white,
                    ),
                    onPressed: _scanBarcode,
                    tooltip: _isScanning ? 'Berhenti scan' : 'Scan barcode',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cartService.getCartItems().isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Keranjang kosong',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Silakan tambahkan produk dengan scan barcode\natau masukkan SKU manual',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _cartService.getCartItems().length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _cartService.getCartItems()[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${currency.format(item.product.unitPrice)} × ${item.quantityInCart}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    maxLines: 1,
                                  ),
                                  Text(
                                    currency.format(item.subtotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: () => _decrementQuantity(item),
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      item.quantityInCart.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () => _incrementQuantity(item),
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha((0.3 * 255).toInt()),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currency.format(_calculateTotal()),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cashTenderedController,
                  decoration: InputDecoration(
                    labelText: 'Uang Tunai Diterima',
                    prefixIcon: const Icon(Icons.payments),
                    prefixText: 'Rp ',
                    border: const OutlineInputBorder(),
                    suffixIcon: _cashTenderedController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _cashTenderedController.clear();
                              _updateChange();
                            },
                          )
                        : null,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _updateChange(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kembalian:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currency.format(_change),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _change > 0 ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _cartService.getCartItems().isEmpty ||
                            _cashTendered < _calculateTotal()
                        ? null
                        : _handleCheckout,
                    child: const Text(
                      'BAYAR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

IconData _getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.external:
      return Icons.videocam;
  }
}
