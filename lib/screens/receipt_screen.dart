import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rosapp/screens/pos_screen.dart'; // For CartItem
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptScreen extends StatelessWidget {
  final List<CartItem> cartItems;
  final double totalPrice;
  final double cashTendered;
  final double change;
  final DateTime transactionTime;

  const ReceiptScreen({
    super.key,
    required this.cartItems,
    required this.totalPrice,
    required this.cashTendered,
    required this.change,
    required this.transactionTime,
  });

  Future<void> _printReceipt(BuildContext context) async {
    final doc = pw.Document();
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    final date = DateFormat('dd MMM yyyy, HH:mm:ss');

    // Add page
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat
            .roll80, // Common for POS printers, or use PdfPageFormat.a4
        build: (pw.Context pdfContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                  child: pw.Text('--- Struk Pembayaran ---',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14))),
              pw.SizedBox(height: 5),
              pw.Center(
                  child: pw.Text('Waktu: ${date.format(transactionTime)}',
                      style: const pw.TextStyle(fontSize: 10))),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 5),
              pw.Text('Barang:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              ...cartItems.map(
                (item) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                        child: pw.Text(
                            '${item.product.name} (${item.quantityInCart}x)',
                            style: const pw.TextStyle(fontSize: 10))),
                    pw.Text(currency.format(item.subtotal),
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Divider(),
              pw.SizedBox(height: 5),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Belanja:',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(currency.format(totalPrice),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ]),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tunai:', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(currency.format(cashTendered),
                        style: const pw.TextStyle(fontSize: 11)),
                  ]),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Kembalian:',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(currency.format(change),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ]),
              pw.SizedBox(height: 15),
              pw.Center(
                  child: pw.Text('Terima Kasih!',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 12))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss');

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Center(
                child: Text('--- Struk Pembayaran ---',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 8),
            Center(child: Text('Waktu: ${dateFormat.format(transactionTime)}')),
            const SizedBox(height: 16),
            const Divider(),
            ...cartItems.map((item) => ListTile(
                  title: Text(item.product.name),
                  subtitle: Text(
                      '${item.quantityInCart} x ${currencyFormat.format(item.product.unitPrice)}'),
                  trailing: Text(currencyFormat.format(item.subtotal)),
                )),
            const Divider(),
            const SizedBox(height: 8),
            _buildSummaryRow(
                'Total Belanja:', currencyFormat.format(totalPrice), context,
                isBold: true),
            _buildSummaryRow(
                'Tunai:', currencyFormat.format(cashTendered), context),
            _buildSummaryRow(
                'Kembalian:', currencyFormat.format(change), context,
                isBold: true),
            const SizedBox(height: 24),
            Center(
                child: Text('Terima Kasih!',
                    style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // Navigate back to POS screen, replacing the receipt screen
                Navigator.of(context).popUntil((route) => route.isFirst);
                // Or, if you want to go specifically to POS and it might not be the first:
                // Navigator.of(context).pushAndRemoveUntil(
                //   MaterialPageRoute(builder: (context) => const PosScreen()),
                //   (Route<dynamic> route) => false,
                // );
              },
              child: const Text('Transaksi Baru'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, BuildContext context,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16)),
        ],
      ),
    );
  }
}
