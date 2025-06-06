import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'package:rosapp/models/transaction_detail.dart';
import 'package:rosapp/services/product_service.dart';
import 'package:rosapp/widgets/app_drawer.dart';


class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

enum ReportFilterType { daily, monthly, yearly, range }

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
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data laporan: $e')));
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
                                  belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
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
      default:
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
