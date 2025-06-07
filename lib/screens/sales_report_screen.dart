import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'package:rosapp/models/transaction_detail.dart';
import 'package:rosapp/models/purchase_detail.dart'; // Tambahkan import ini
import 'package:rosapp/services/product_service.dart';
import 'package:rosapp/widgets/app_drawer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border; // Sembunyikan Border dari paket excel
import 'dart:io'; // Untuk File
import 'package:open_filex/open_filex.dart'; // Untuk membuka file
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;


class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

enum ReportFilterType { daily, monthly, yearly, range }
enum ExportFormat { excel, pdf }

// Helper function (optional, could be part of the class or a utility file)
// String filterTypeToString(ReportFilterType filterType) {
//   return filterType.toString().split('.').last;
// }


class _SalesReportScreenState extends State<SalesReportScreen> {
  final ProductService _productService = ProductService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  final dateTimeFormatter = DateFormat('dd MMM yyyy, HH:mm');

  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now(); // Default to today
  ReportFilterType _filterType = ReportFilterType.daily;
  DateTimeRange? _selectedDateRange;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  double _totalSalesAllTime = 0.0;
  double _totalSalesForPeriod = 0.0;
  int _transactionsForPeriodCount = 0;
  double _totalPurchasesForPeriod = 0.0;
  double _estimatedCogsForPeriod = 0.0;
  List<TransactionDetail> _recentTransactions = [];
  double _estimatedProfitForPeriod = 0.0;
  List<FlSpot> _salesChartData = [];
  List<TransactionDetail> _transactionsForPeriodReport = []; // Semua transaksi untuk periode laporan
  List<PurchaseDetail> _purchasesForPeriodReport = []; // State baru untuk detail pembelian

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now
    );
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    setState(() => _isLoading = true);

    DateTime startDate;
    DateTime endDate;

    switch (_filterType) {
      case ReportFilterType.daily:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
        break;
      case ReportFilterType.monthly:
        startDate = DateTime(_selectedYear, _selectedMonth, 1);
        endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59); // Last day of month
        break;
      case ReportFilterType.yearly:
        startDate = DateTime(_selectedYear, 1, 1);
        endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59);
        break;
      case ReportFilterType.range:
        if (_selectedDateRange == null) {
          // Should not happen if initialized properly, but as a safeguard
          setState(() => _isLoading = false);
          return;
        }
        startDate = _selectedDateRange!.start;
        // Ensure endDate covers the whole day
        endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        break;
    }

    try {
      final totalSales = await _productService.getTotalSalesAllTime();
      final salesForPeriod = await _productService.getTotalSalesForPeriod(startDate, endDate);
      final countForPeriod = await _productService.getTransactionCountForPeriod(startDate, endDate);
      final cogsForPeriod = await _productService.getEstimatedCogsForPeriod(startDate, endDate);
      final purchasesForPeriod = await _productService.getTotalPurchasesForPeriod(startDate, endDate);
      final recent = await _productService.getRecentTransactions(limit: 5);
      final chartDataRaw = await _productService.getDailySalesForChart(startDate, endDate);
      final purchasesReport = await _productService.getPurchasesForPeriodReport(startDate, endDate); // Ambil data pembelian
      final transactionsForReport = await _productService.getTransactionsForPeriod(startDate, endDate); // Ambil SEMUA transaksi untuk periode laporan

      List<FlSpot> chartSpots = [];
      if (chartDataRaw.isNotEmpty) {
        chartSpots = chartDataRaw.asMap().entries.map((entry) {
          // final int index = entry.key; // Use index for X-axis if dates are consecutive
          final data = entry.value;
          final date = DateTime.parse(data['sales_date'] as String);
          
          // X-axis: For simplicity, using day of the month or day of the year.
          // A more robust solution might use timestamps or a normalized index.
          double xValue;
          double yValue = (data['daily_total'] as num).toDouble();

          switch (_filterType) {
            case ReportFilterType.daily:
              // Use hours as x-axis for daily view
              xValue = date.hour.toDouble();
              break;
            case ReportFilterType.monthly:
              // Day of month
              xValue = date.day.toDouble();
              break;
            case ReportFilterType.range:
              // Days since start of range
              if (_selectedDateRange != null) {
                xValue = date.difference(_selectedDateRange!.start).inDays.toDouble();
              } else {
                xValue = date.day.toDouble();
              }
              break;
            case ReportFilterType.yearly:
              // Month number
              xValue = date.month.toDouble();
              break;
          }

          return FlSpot(xValue, yValue);
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        _totalSalesAllTime = totalSales;
        _totalSalesForPeriod = salesForPeriod;
        _transactionsForPeriodCount = countForPeriod;
        _estimatedCogsForPeriod = cogsForPeriod;
        _totalPurchasesForPeriod = purchasesForPeriod;
        _recentTransactions = recent;
        _estimatedProfitForPeriod = salesForPeriod - cogsForPeriod;
        _salesChartData = chartSpots;
        _purchasesForPeriodReport = purchasesReport; // Simpan data pembelian
        _transactionsForPeriodReport = transactionsForReport; // Simpan semua transaksi untuk laporan
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data laporan: $e')));
    }
  }

  Future<void> _exportReport(ExportFormat format) async {
    if (!Platform.isWindows) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur ekspor saat ini hanya tersedia untuk Windows.')));
      return;
    }

    // On Windows, apps typically have write access to their application documents directory.
    // The permission_handler's `Permission.storage` is not applicable/needed in the same way as on mobile
    // for getApplicationDocumentsDirectory().
    // If targeting user-selectable directories (e.g., "Downloads"), a file picker (like file_selector)
    // would be more appropriate and handles permissions implicitly.
    // For getApplicationDocumentsDirectory() on Windows, permission is assumed.

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final String periodStr = _getPeriodTitle('').replaceAll(RegExp(r'[^\w\s]+'),'').replaceAll(' ', '_').toLowerCase();
      final fileName = 'laporan_penjualan_${periodStr}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      if (format == ExportFormat.excel) {
        await _generateExcelReport('$path/$fileName.xlsx');
      } else if (format == ExportFormat.pdf) {
        await _generatePdfReport('$path/$fileName.pdf');
      }
    } catch (e) {
      debugPrint('Error during export: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengekspor laporan: $e')));
    }
  }

  Future<void> _generateExcelReport(String filePath) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Laporan Penjualan'];
    excel.setDefaultSheet(sheetObject.sheetName);

    // Header Laporan
    sheetObject.appendRow([TextCellValue('Laporan Penjualan')]);
    sheetObject.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0));
    sheetObject.appendRow([TextCellValue(_getPeriodTitle('Periode'))]);
    sheetObject.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1), CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1));
    sheetObject.appendRow([]); // Baris kosong

    // Ringkasan
    sheetObject.appendRow([TextCellValue('Ringkasan Laporan')]);
    sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheetObject.maxRows -1 )).cellStyle = CellStyle(bold: true);
    sheetObject.appendRow([TextCellValue('Total Penjualan (Semua Waktu)'), TextCellValue(currencyFormatter.format(_totalSalesAllTime))]);
    sheetObject.appendRow([TextCellValue(_getPeriodTitle('Penjualan Periode Ini')), TextCellValue(currencyFormatter.format(_totalSalesForPeriod))]);
    sheetObject.appendRow([TextCellValue(_getPeriodTitle('Jumlah Transaksi')), TextCellValue(_transactionsForPeriodCount.toString())]);
    sheetObject.appendRow([TextCellValue(_getPeriodTitle('Total Pembelian')), TextCellValue(currencyFormatter.format(_totalPurchasesForPeriod))]);
    sheetObject.appendRow([TextCellValue(_getPeriodTitle('Estimasi HPP')), TextCellValue(currencyFormatter.format(_estimatedCogsForPeriod))]);
    sheetObject.appendRow([TextCellValue(_getPeriodTitle('Estimasi Laba Kotor')), TextCellValue(currencyFormatter.format(_estimatedProfitForPeriod))]);
    sheetObject.appendRow([]); // Baris kosong

    // Detail Pembelian
    if (_purchasesForPeriodReport.isNotEmpty) {
      sheetObject.appendRow([TextCellValue('Detail Pembelian dari Supplier')]);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheetObject.maxRows -1 )).cellStyle = CellStyle(bold: true);
      sheetObject.appendRow([
        TextCellValue('Tanggal'),
        TextCellValue('Nama Produk'),
        TextCellValue('Supplier'),
        TextCellValue('Jumlah'),
        TextCellValue('Harga Beli/Unit'),
        TextCellValue('Total Biaya')
      ]);
      // Style header tabel
      for (var i = 0; i < 6; i++) {
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: sheetObject.maxRows -1 )).cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D3D3D3'));
      }

      for (var purchase in _purchasesForPeriodReport) {
        sheetObject.appendRow([
          TextCellValue(DateFormat('dd MMM yyyy').format(purchase.purchaseDate)),
          TextCellValue(purchase.productName),
          TextCellValue(purchase.supplierName ?? '-'),
          IntCellValue(purchase.quantityPurchased),
          DoubleCellValue(purchase.purchasePricePerUnit),
          DoubleCellValue(purchase.totalCost)
        ]);
      }
      sheetObject.appendRow([]); // Baris kosong
    }

    // Detail Transaksi
    if (_transactionsForPeriodReport.isNotEmpty) {
      sheetObject.appendRow([TextCellValue(_getPeriodTitle('Detail Transaksi Periode Ini'))]);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheetObject.maxRows -1 )).cellStyle = CellStyle(bold: true);
      sheetObject.appendRow([TextCellValue('Tanggal & Waktu'), TextCellValue('Total Transaksi')]);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheetObject.maxRows -1 )).cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D3D3D3'));
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: sheetObject.maxRows -1 )).cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D3D3D3'));
      for (var tx in _transactionsForPeriodReport) {
        sheetObject.appendRow([
          TextCellValue(dateTimeFormatter.format(tx.date)),
          DoubleCellValue(tx.totalPrice)
        ]);
      }
    }

    // Simpan file
    var fileBytes = excel.save();
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan disimpan di: $filePath'),
          action: SnackBarAction(
            label: 'Buka',
            onPressed: () => OpenFilex.open(filePath),
          ),
        ),
      );
    }
  }

  Future<void> _generatePdfReport(String filePath) async {
    final pdf = pw.Document();
    final baseFont = pw.Font.helvetica(); // Pastikan Anda memiliki font ini di assets
    final boldFont = pw.Font.helveticaBold(); // Atau gunakan pw.Font.helveticaBold() dll.

    final baseStyle = pw.TextStyle(font: baseFont, fontSize: 10);
    final boldStyle = pw.TextStyle(font: boldFont, fontSize: 10);
    final headerStyle = pw.TextStyle(font: boldFont, fontSize: 16);
    final subHeaderStyle = pw.TextStyle(font: boldFont, fontSize: 12);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
            child: pw.Text(
              'Laporan Penjualan - RosApp',
              style: baseStyle.copyWith(color: PdfColors.grey),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: baseStyle.copyWith(color: PdfColors.grey),
            ),
          );
        },
        build: (pw.Context context) => <pw.Widget>[
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text('Laporan Penjualan', style: headerStyle),
                pw.Text(_getPeriodTitle('Periode'), style: baseStyle.copyWith(fontSize: 11)),
                pw.SizedBox(height: 20),
              ]
            )
          ),
          pw.Header(level: 1, text: 'Ringkasan Laporan', textStyle: subHeaderStyle),
          pw.TableHelper.fromTextArray(
            context: context,
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: baseStyle,
            data: <List<String>>[
              ['Total Penjualan (Semua Waktu):', currencyFormatter.format(_totalSalesAllTime)],
              [_getPeriodTitle('Penjualan Periode Ini:'), currencyFormatter.format(_totalSalesForPeriod)],
              [_getPeriodTitle('Jumlah Transaksi:'), _transactionsForPeriodCount.toString()],
              [_getPeriodTitle('Total Pembelian:'), currencyFormatter.format(_totalPurchasesForPeriod)],
              [_getPeriodTitle('Estimasi HPP:'), currencyFormatter.format(_estimatedCogsForPeriod)],
              [_getPeriodTitle('Estimasi Laba Kotor:'), currencyFormatter.format(_estimatedProfitForPeriod)],
            ],
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.5),
            },
            border: null,
          ),
          pw.SizedBox(height: 20),
          if (_purchasesForPeriodReport.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Detail Pembelian dari Supplier', textStyle: subHeaderStyle),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: boldStyle,
              cellStyle: baseStyle,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: { 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight },
              data: <List<String>>[
                <String>['Tanggal', 'Nama Produk', 'Supplier', 'Jumlah', 'Harga Beli/Unit', 'Total Biaya'],
                ..._purchasesForPeriodReport.map((p) => [
                      DateFormat('dd MMM yy').format(p.purchaseDate),
                      p.productName,
                      p.supplierName ?? '-',
                      p.quantityPurchased.toString(),
                      currencyFormatter.format(p.purchasePricePerUnit),
                      currencyFormatter.format(p.totalCost),
                    ]),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
          if (_transactionsForPeriodReport.isNotEmpty) ...[
            pw.Header(level: 1, text: _getPeriodTitle('Detail Transaksi Periode Ini'), textStyle: subHeaderStyle),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: boldStyle,
              cellStyle: baseStyle,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {1: pw.Alignment.centerRight},
              data: <List<String>>[
                <String>['Tanggal & Waktu', 'Total Transaksi'],
                ..._transactionsForPeriodReport.map((tx) => [
                      dateTimeFormatter.format(tx.date),
                      currencyFormatter.format(tx.totalPrice),
                    ]),
              ],
            ),
          ],
        ],
      ),
    );

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan PDF disimpan di: $filePath'),
          action: SnackBarAction(
            label: 'Buka',
            onPressed: () => OpenFilex.open(filePath),
          ),
        ),
      );
    }
  }

  Future<void> _pickDailyDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _filterType = ReportFilterType.daily; // Pastikan filter aktif adalah harian
        _selectedDate = picked;
      });
      _loadSalesData();
    }
  }

  Future<void> _pickMonthYear(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      // User picks any day, we extract month/year
    );
    if (picked != null) {
      setState(() {
        _filterType = ReportFilterType.monthly;
        _selectedYear = picked.year;
        _selectedMonth = picked.month;
      });
      _loadSalesData();
    }
  }

  Future<void> _pickYear(BuildContext context) async {
     final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _filterType = ReportFilterType.yearly;
        _selectedYear = picked.year;
      });
      _loadSalesData();
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _filterType = ReportFilterType.range; // Pastikan filter aktif adalah rentang
        _selectedDateRange = picked;
      });
      _loadSalesData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<ExportFormat>(
            icon: const Icon(Icons.file_download),
            tooltip: 'Ekspor Laporan',
            onSelected: (ExportFormat result) {
              _exportReport(result);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ExportFormat>>[
              const PopupMenuItem<ExportFormat>(
                value: ExportFormat.excel,
                child: ListTile(leading: Icon(Icons.table_chart_outlined), title: Text('Excel (.xlsx)')),
              ),
              const PopupMenuItem<ExportFormat>(
                value: ExportFormat.pdf,
                child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('PDF (.pdf)')),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSalesData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: <Widget>[
                  _buildSummaryCard(
                    title: 'Total Penjualan (Semua Waktu)',
                    value: currencyFormatter.format(_totalSalesAllTime),
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildFilterSelection(),
                  const SizedBox(height: 16),
                  
                  if (_salesChartData.isNotEmpty)
                    SizedBox(
                      height: 250, // Increased height for better chart visibility
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 20, 12), // Adjusted padding
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                getDrawingHorizontalLine: (value) {
                                  return const FlLine(color: Colors.grey, strokeWidth: 0.5);
                                },
                                getDrawingVerticalLine: (value) {
                                  return const FlLine(color: Colors.grey, strokeWidth: 0.5);
                                },
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true, 
                                    reservedSize: 30, 
                                    getTitlesWidget: _bottomTitleWidgets, 
                                    interval: _calculateTitleInterval(_salesChartData)
                                  )
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true, 
                                    reservedSize: 50, // Increased for better label fitting
                                    getTitlesWidget: _leftTitleWidgets,
                                    // interval: _calculateYAxisInterval(), // Optional: dynamic interval
                                  )
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade400, width: 1)),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _salesChartData,
                                  isCurved: true,
                                  color: Colors.blue,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: true, color: Colors.blue.withAlpha((0.2 * 255).toInt())),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_salesChartData.isNotEmpty) const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: _getPeriodTitle('Penjualan'),
                          value: currencyFormatter.format(_totalSalesForPeriod),
                          icon: Icons.today,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          title: _getPeriodTitle('Transaksi'),
                          value: _transactionsForPeriodCount.toString(),
                          icon: Icons.receipt_long,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(
                    title: _getPeriodTitle('Total Pembelian'),
                    value: currencyFormatter.format(_totalPurchasesForPeriod),
                    icon: Icons.shopping_bag_outlined,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(
                    title: _getPeriodTitle('Estimasi HPP'),
                    value: currencyFormatter.format(_estimatedCogsForPeriod),
                    icon: Icons.calculate_outlined,
                    color: Colors.deepOrange,
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(
                    title: _getPeriodTitle('Estimasi Laba Kotor'),
                    value: currencyFormatter.format(_estimatedProfitForPeriod),
                    icon: Icons.attach_money,
                    color: _estimatedProfitForPeriod >= 0 ? Colors.teal : Colors.pink,
                  ),
                  const SizedBox(height: 24),
                  // Bagian Baru: Detail Pembelian oleh Supplier
                  Text(
                    _getPeriodTitle('Detail Pembelian dari Supplier'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _purchasesForPeriodReport.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Text('Belum ada data pembelian untuk periode ini.'),
                          ),
                        )
                      : Card(
                          elevation: 2,
                          child: Column(
                            children: _purchasesForPeriodReport.map((purchase) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: const Icon(Icons.storefront_outlined, color: Colors.orange),
                                ),
                                title: Text(
                                  '${purchase.productName} - ${currencyFormatter.format(purchase.totalCost)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  'Supplier: ${purchase.supplierName ?? "-"}\n'
                                  'Tgl: ${DateFormat('dd MMM yyyy').format(purchase.purchaseDate)} | Jml: ${purchase.quantityPurchased} @ ${currencyFormatter.format(purchase.purchasePricePerUnit)}'
                                ),
                                isThreeLine: true,
                              );
                            }).toList(),
                          ),
                        ),
                  const SizedBox(height: 24),
                  Text(
                    'Transaksi Terbaru',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _recentTransactions.isEmpty
                      ? const Center(
                          child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: Text('Belum ada transaksi.'),
                        ))
                      : Card(
                          elevation: 2,
                          child: Column(
                            children: _recentTransactions.map((tx) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: const Icon(Icons.shopping_cart, color: Colors.blue),
                                ),
                                title: Text(currencyFormatter.format(tx.totalPrice)),
                                subtitle: Text(dateTimeFormatter.format(tx.date)),
                                );
                            }).toList(),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<ReportFilterType>(
          segments: const <ButtonSegment<ReportFilterType>>[
            ButtonSegment<ReportFilterType>(value: ReportFilterType.daily, label: Text('Harian'), icon: Icon(Icons.today)),
            ButtonSegment<ReportFilterType>(value: ReportFilterType.monthly, label: Text('Bulanan'), icon: Icon(Icons.calendar_month)),
            ButtonSegment<ReportFilterType>(value: ReportFilterType.yearly, label: Text('Tahunan'), icon: Icon(Icons.calendar_view_day)),
            ButtonSegment<ReportFilterType>(value: ReportFilterType.range, label: Text('Rentang'), icon: Icon(Icons.date_range)),
          ],
          selected: <ReportFilterType>{_filterType},
          onSelectionChanged: (Set<ReportFilterType> newSelection) {
            setState(() {
              _filterType = newSelection.first;
              // Reset/adjust date selections based on the new filter type for clarity
              final now = DateTime.now();
              _selectedDate = now;
              _selectedMonth = now.month;
              _selectedYear = now.year;
              _selectedDateRange = DateTimeRange(
                start: now.subtract(const Duration(days: 6)),
                end: now
              );
            });
            _loadSalesData();
          },
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.blueGrey[50],
            foregroundColor: Colors.blueGrey[700],
            selectedForegroundColor: Colors.white,
            selectedBackgroundColor: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        if (_filterType == ReportFilterType.daily)
          ElevatedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text('Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedDate)}'),
            onPressed: () => _pickDailyDate(context),
             style: _datePickerButtonStyle(),
          ),
        if (_filterType == ReportFilterType.monthly)
          ElevatedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text('Bulan: ${DateFormat('MMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}'),
            onPressed: () => _pickMonthYear(context),
            style: _datePickerButtonStyle(),
          ),
        if (_filterType == ReportFilterType.yearly)
          ElevatedButton.icon(
            icon: const Icon(Icons.calendar_view_day),
            label: Text('Tahun: $_selectedYear'),
            onPressed: () => _pickYear(context),
            style: _datePickerButtonStyle(),
          ),
        if (_filterType == ReportFilterType.range)
          ElevatedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(_selectedDateRange != null
                ? 'Rentang: ${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}'
                : 'Pilih Rentang Tanggal'),
            onPressed: () => _pickDateRange(context),
            style: _datePickerButtonStyle(),
          ),
      ],
    );
  }

  ButtonStyle _datePickerButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.blueGrey[50],
      foregroundColor: Colors.blueGrey[800],
      elevation: 1,
      minimumSize: const Size(double.infinity, 40), // Make button full width
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  String _getPeriodTitle(String baseTitle) {
    switch (_filterType) {
      case ReportFilterType.daily:
        return '$baseTitle (${DateFormat('dd MMM yyyy').format(_selectedDate)})';
      case ReportFilterType.monthly:
        return '$baseTitle (${DateFormat('MMM yyyy').format(DateTime(_selectedYear, _selectedMonth))})';
      case ReportFilterType.yearly:
        return '$baseTitle ($_selectedYear)';
      case ReportFilterType.range:
        if (_selectedDateRange != null) {
          if (_selectedDateRange!.start.year == _selectedDateRange!.end.year &&
              _selectedDateRange!.start.month == _selectedDateRange!.end.month &&
              _selectedDateRange!.start.day == _selectedDateRange!.end.day) {
                return '$baseTitle (${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)})';
              }
          return '$baseTitle (${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)})';
        }
        return baseTitle;
    }
  }


  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 15), overflow: TextOverflow.ellipsis)),
                Icon(icon, color: color, size: 28),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTitleInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    
    // Determine the range of x values
    double minX = spots.first.x;
    double maxX = spots.first.x;
    for (var spot in spots) {
      if (spot.x < minX) minX = spot.x;
      if (spot.x > maxX) maxX = spot.x;
    }
    double xRange = maxX - minX;

    if (xRange <= 0) return 1; // Single point or no range

    int numberOfLabelsToShow = 5; // Desired number of labels

    if (_filterType == ReportFilterType.monthly || 
        (_filterType == ReportFilterType.range && _selectedDateRange != null && _selectedDateRange!.duration.inDays <= 31)) {
        // For daily/monthly views (up to ~31 points)
        if (xRange <= 10) return 1;
        if (xRange <= 20) return 2;
        return 5;
    } else { // Yearly or longer ranges
        return (xRange / numberOfLabelsToShow).ceilToDouble();
    }
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    String text;
    final int intValue = value.toInt();

    if (_filterType == ReportFilterType.daily) {
    // For daily view (showing hours if needed)
    text = DateFormat('HH:mm').format(_selectedDate.add(Duration(hours: intValue)));
  } 
  else if (_filterType == ReportFilterType.monthly) {
    // Day of month
    text = intValue.toString();
  }
  else if (_filterType == ReportFilterType.range) {
    if (_selectedDateRange != null) {
      final days = _selectedDateRange!.duration.inDays;
      if (days <= 31) {
        // Show day numbers for short ranges
        text = intValue.toString();
      } else {
        // For longer ranges, show actual dates
        try {
          final date = _selectedDateRange!.start.add(Duration(days: intValue - 1));
          text = DateFormat('d MMM').format(date);
        } catch (e) {
          text = intValue.toString();
        }
      }
    } else {
      text = intValue.toString();
    }
  }
  else { // Yearly
    try {
      final date = DateTime(_selectedYear, 1, 1).add(Duration(days: intValue - 1));
      text = DateFormat('MMM').format(date); // Just show month abbreviation
    } catch (e) {
      text = intValue.toString();
    }
  }

    return SideTitleWidget(meta: meta, space: 4, child: Text(text, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis,));
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    String text;
    // Avoid showing labels for min/max if they are too close or 0, unless it's the only data
    if ((value == meta.max || value == meta.min) && meta.max != meta.min && value != 0) {
       // Allow fl_chart to decide based on interval
    } else if (value == 0 && meta.max == 0) {
      // If all values are 0
    } else if (value == 0 && meta.min == 0 && meta.max > 0) {
      // Show 0 if it's the actual min
    } else if (value == meta.max && meta.max == meta.min) {
      // Single value, show it
    }
     else if (value % meta.appliedInterval != 0 && value != meta.min && value != meta.max) {
      // return Container(); // Let fl_chart handle interval
    }


    if (value >= 1000000) {
      text = '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}Jt';
    } else if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(0)}Rb';
    } else {
      text = value.toInt().toString();
    }
    return SideTitleWidget(meta: meta, space: 4, child: Text(text, style: const TextStyle(fontSize: 10)));
  }
}
