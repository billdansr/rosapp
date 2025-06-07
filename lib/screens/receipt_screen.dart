import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rosapp/models/cart_item.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptScreen extends StatelessWidget {
  // Constants
  static const String kStoreName = 'Warung Rosazza';
  static const String kStoreAddressLine1 = 'Jl. Mega Nusa Endah No.Raya';
  static const String kStoreAddressLine2 = 'Karyamulya, Kesambi, Cirebon';
  static const String kThankYouMessage = 'TERIMA KASIH!';
  static const String kNoReturnsMessage = 'Barang tidak dapat ditukar';
  static const String kSeparator = '-------------------------------';
  static const String kScreenSeparator =
      '--------------------------------------------------';

  // Formatters
  static final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  static final DateFormat _receiptDateFormatter =
      DateFormat('dd MMM yyyy HH:mm:ss');

  final List<CartItem> cartItems;
  final double totalPrice;
  final double cashTendered;
  final double change;
  final DateTime transactionTime;
  final int transactionDbId; // Use this for the DB transaction ID

  ReceiptScreen({
    super.key,
    required this.cartItems,
    required this.totalPrice,
    required this.cashTendered,
    required this.change,
    required this.transactionTime,
    required this.transactionDbId, // Make it required
  }) : assert(cartItems.isNotEmpty);

  Future<void> _printReceipt(BuildContext context) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll57,
        build: (pw.Context pdfContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  kStoreName,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  kStoreAddressLine1,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  kStoreAddressLine2,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(kSeparator, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 3),
              pw.Text(
                'Tanggal: ${_receiptDateFormatter.format(transactionTime)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'No. Transaksi: $transactionDbId', // Use the DB transaction ID
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 5),
              pw.Text(kSeparator, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 5),
              ...cartItems.map(
                (item) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded( // Left side: Product name and details
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.product.name,
                            style: const pw.TextStyle(fontSize: 10),
                            maxLines: 2,
                            overflow: pw.TextOverflow.span,
                          ),
                          pw.Text(
                            '(${item.quantityInCart}x @ ${_currencyFormat.format(item.product.unitPrice)})',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 5), // Spacer
                    pw.Text( // Right side: Subtotal
                      _currencyFormat.format(item.subtotal),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(kSeparator, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Belanja:',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    _currencyFormat.format(totalPrice),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Tunai:',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    _currencyFormat.format(cashTendered),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Kembalian:',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    _currencyFormat.format(change),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text(kSeparator, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  kThankYouMessage,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  kNoReturnsMessage,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      final printingInfo = await Printing.info();
      if (!printingInfo.canPrint) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Layanan cetak tidak tersedia di perangkat ini.')),
          );
        }
        return; // Do not proceed if printing is not available
      }
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Struk Pembayaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printReceipt(context),
          ),
        ],
      ),
      body: _buildReceiptContent(context),
    );
  }

  Widget _buildReceiptContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildStoreInfo(),
          const SizedBox(height: 12),
          _buildTransactionInfo(),
          const SizedBox(height: 16),
          ..._buildItemsList(),
          const SizedBox(height: 8),
          _buildPaymentSummary(),
          const SizedBox(height: 16),
          _buildFooter(),
          const SizedBox(height: 40),
          _buildNewTransactionButton(context),
        ],
      ),
    );
  }

  Widget _buildStoreInfo() {
    return Column(
      children: [
        Center(
          child: Text(
            kStoreName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        Center(
          child: Text(
            kStoreAddressLine1,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Center(
          child: Text(
            kStoreAddressLine2,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionInfo() {
    return Column(
      children: [
        Text(
          kScreenSeparator,
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Tanggal:',
          _receiptDateFormatter.format(transactionTime),
        ),
        _buildInfoRow(
          'No. Transaksi:',
          transactionDbId.toString(), // Use the DB transaction ID
        ),
      ],
    );
  }

  List<Widget> _buildItemsList() {
    return [
      Text(
        kScreenSeparator,
        style: const TextStyle(fontSize: 14),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      ...cartItems.map((item) => ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        title: Text('${item.product.name} (${item.quantityInCart}x)'),
        subtitle: Text(_currencyFormat.format(item.product.unitPrice)),
        trailing: Text(_currencyFormat.format(item.subtotal)),
      )),
    ];
  }

  Widget _buildPaymentSummary() {
    return Column(
      children: [
        Text(
          kScreenSeparator,
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _buildSummaryRow(
          'Total Belanja:',
          _currencyFormat.format(totalPrice),
          isBold: true,
        ),
        _buildSummaryRow(
          'Tunai:',
          _currencyFormat.format(cashTendered),
        ),
        const SizedBox(height: 4),
        _buildSummaryRow(
          'Kembalian:',
          _currencyFormat.format(change),
          isBold: true,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          kScreenSeparator,
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            kThankYouMessage,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            kNoReturnsMessage,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNewTransactionButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Pop the ReceiptScreen to return to the PosScreen, which has already reset its state.
        Navigator.of(context).pop();
      },
      child: const Text('Transaksi Baru'),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 16,
            ),
          ),
        ],
      ),
    );
  }
}
