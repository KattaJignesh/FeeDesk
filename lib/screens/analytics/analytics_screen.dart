import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _service = AnalyticsService();

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _overview = {};

  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _degrees = [];
  List<Map<String, dynamic>> _studyYears = [];
  List<Map<String, dynamic>> _quotas = [];
  List<Map<String, dynamic>> _categories = [];

  static const Color _blue = Color(0xFF3559D8);
  static const Color _background = Color(0xFFF5F6FA);

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getOverview(),
        _service.getFeeByDimension('School'),
        _service.getFeeByDimension('Program'),
        _service.getFeeByDimension('Degree'),
        _service.getFeeByDimension('Study Year'),
        _service.getFeeByDimension('CQ/MQ'),
        _service.getCategoryBreakdown(),
      ]);

      if (!mounted) return;

      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _schools = results[1] as List<Map<String, dynamic>>;
        _programs = results[2] as List<Map<String, dynamic>>;
        _degrees = results[3] as List<Map<String, dynamic>>;
        _studyYears = results[4] as List<Map<String, dynamic>>;
        _quotas = results[5] as List<Map<String, dynamic>>;
        _categories = results[6] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double _rupees(dynamic paise) {
    return (paise as num? ?? 0).toDouble() / 100;
  }

  String _money(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 27),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Color(0xFF20243A),
              ),
            ),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // REUSABLE BAR CHART
  // ------------------------------------------------------------

  Widget _barChart(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('No data available')),
      );
    }

    final items = rows.take(6).toList();

    final values = items.map((e) => _rupees(e['total_paise'])).toList();

    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 290,
      child: BarChart(
        BarChartData(
          maxY: maxValue <= 0 ? 100 : maxValue * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 55),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 55,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 || index >= items.length) {
                    return const SizedBox.shrink();
                  }

                  final label = (items[index]['label'] ?? '').toString();

                  return SideTitleWidget(
                    meta: meta,
                    child: SizedBox(
                      width: 65,
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(items.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index],
                  width: 27,
                  color: _blue,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EXPENDITURE BREAKDOWN
  // ------------------------------------------------------------

  Widget _categoryBreakdown() {
    if (_categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 25),
        child: Center(child: Text('No expenditure data available')),
      );
    }

    final total = _categories.fold<double>(
      0,
      (sum, item) => sum + _rupees(item['total_paise']),
    );

    return Column(
      children: _categories.map((item) {
        final amount = _rupees(item['total_paise']);
        final percentage = total == 0 ? 0.0 : amount / total;

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['label'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    _money(amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFE9ECF5),
                  valueColor: const AlwaysStoppedAnimation(_blue),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ------------------------------------------------------------
  // MAIN SCREEN
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final recordCount = (_overview['record_count'] as num? ?? 0).toInt();

    final schoolCount = (_overview['school_count'] as num? ?? 0).toInt();

    final programCount = (_overview['program_count'] as num? ?? 0).toInt();

    final degreeCount = (_overview['degree_count'] as num? ?? 0).toInt();

    final totalFee = _money(_rupees(_overview['total_fee_paise']));

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 42),
                      const SizedBox(height: 12),
                      const Text('Could not load analytics'),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAnalytics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadAnalytics,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Header.
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Analytics Overview',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Insights from your active fee dataset',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh analytics',
                          onPressed: _loadAnalytics,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Summary cards.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 850 ? 4 : 2;

                        final cardWidth =
                            (constraints.maxWidth - (columns - 1) * 14) /
                            columns;

                        final cards = [
                          _summaryCard(
                            'Total fee amount',
                            totalFee,
                            Icons.currency_rupee,
                            _blue,
                          ),
                          _summaryCard(
                            'Fee records',
                            recordCount.toString(),
                            Icons.receipt_long,
                            Colors.deepPurple,
                          ),
                          _summaryCard(
                            'Schools',
                            schoolCount.toString(),
                            Icons.school,
                            Colors.teal,
                          ),
                          _summaryCard(
                            'Programmes',
                            programCount.toString(),
                            Icons.menu_book,
                            Colors.orange,
                          ),
                          _summaryCard(
                            'Degrees',
                            degreeCount.toString(),
                            Icons.school_outlined,
                            Colors.indigo,
                          ),
                        ];

                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: cards.map((card) {
                            return SizedBox(width: cardWidth, child: card);
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    _sectionCard(
                      title: 'School-wise Fee Distribution',
                      child: _barChart(_schools),
                    ),

                    const SizedBox(height: 18),

                    _sectionCard(
                      title: 'Programme-wise Fee Distribution',
                      child: _barChart(_programs),
                    ),

                    const SizedBox(height: 18),

                    _sectionCard(
                      title: 'Degree-wise Fee Distribution',
                      child: _barChart(_degrees),
                    ),

                    const SizedBox(height: 18),

                    _sectionCard(
                      title: 'Study Year-wise Fee Distribution',
                      child: _barChart(_studyYears),
                    ),

                    const SizedBox(height: 18),

                    _sectionCard(
                      title: 'CQ/MQ Fee Distribution',
                      child: _barChart(_quotas),
                    ),

                    const SizedBox(height: 18),

                    _sectionCard(
                      title: 'Expenditure Breakdown',
                      child: _categoryBreakdown(),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Amounts are calculated from fee records in '
                      'the active imported dataset. They are not '
                      'verified collections or payments. Charts '
                      'show the six highest-value groups.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
