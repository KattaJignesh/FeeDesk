
import 'package:flutter/material.dart';

import '../../services/fee_explorer_service.dart';

class FeeExplorerScreen extends StatefulWidget {
  const FeeExplorerScreen({super.key});

  @override
  State<FeeExplorerScreen> createState() => _FeeExplorerScreenState();
}

class _FeeExplorerScreenState extends State<FeeExplorerScreen> {
  final FeeExplorerService _service = FeeExplorerService();

  static const dimensions = [
    'Admitted Batch',
    'Academic Year',
    'School',
    'Degree',
    'Program',
    'Study Year',
    'CQ/MQ',
  ];

  final Map<String, String?> _selected = {};
  final Map<String, List<String>> _options = {};

  Map<String, Object?> _summary = {};
  List<Map<String, Object?>> _studyYearComparisons = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Map<String, String> get _filters {
    return {
      for (final key in dimensions)
        if (_selected[key] != null) key: _selected[key]!,
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final newOptions = <String, List<String>>{};

      for (var i = 0; i < dimensions.length; i++) {
        final dimension = dimensions[i];
        final previousFilters = <String, String>{};

        for (var j = 0; j < i; j++) {
          final previous = dimensions[j];

          if (_selected[previous] != null) {
            previousFilters[previous] = _selected[previous]!;
          }
        }

        final values = await _service.getOptions(
          dimension,
          previousFilters,
        );

        newOptions[dimension] = values;

        if (_selected[dimension] != null &&
            !values.contains(_selected[dimension])) {
          _selected[dimension] = null;
        }
      }

      final summary = await _service.getFeeSummary(_filters);

      final comparisons =
          await _service.getStudyYearComparison(_filters);

      if (!mounted) return;

      setState(() {
        _options
          ..clear()
          ..addAll(newOptions);

        _summary = summary;
        _studyYearComparisons = comparisons;
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

  Future<void> _changeSelection(
    String dimension,
    String? value,
  ) async {
    final index = dimensions.indexOf(dimension);

    setState(() {
      _selected[dimension] = value;

      // Clear all dependent selections.
      for (var i = index + 1; i < dimensions.length; i++) {
        _selected[dimensions[i]] = null;
      }
    });

    await _refresh();
  }

  String _rupees(Object? paise) {
    final value = paise is num ? paise.toInt() : 0;
    final rupees = value / 100;

    return '₹${rupees.toStringAsFixed(2)}';
  }

  Widget _filterDropdown(String dimension) {
    final values = _options[dimension] ?? [];
    final selectedValue = _selected[dimension];

    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: dimension,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
      ),
      hint: const Text('All'),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All'),
        ),
        ...values.map(
          (value) => DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: values.isEmpty
          ? null
          : (value) => _changeSelection(dimension, value),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.indigo, size: 25),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeBreakdown() {
    final categories =
        (_summary['categoryTotals'] as Map<String, int>?) ?? {};

    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No fee components found for this selection.',
        ),
      );
    }

    return Column(
      children: [
        for (final entry in categories.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                Text(
                  _rupees(entry.value),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------
  // STUDY YEAR VERIFICATION PANEL
  // ------------------------------------------------------------

  String _ordinal(int year) {
    if (year % 100 >= 11 && year % 100 <= 13) {
      return '${year}th Year';
    }

    switch (year % 10) {
      case 1:
        return '${year}st Year';
      case 2:
        return '${year}nd Year';
      case 3:
        return '${year}rd Year';
      default:
        return '${year}th Year';
    }
  }

  Widget _buildStudyYearVerification() {
    if (_studyYearComparisons.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No Study Year comparison data is available.',
          ),
        ),
      );
    }

    final mismatchCount = _studyYearComparisons
        .where((row) => row['isMismatch'] == true)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study Year Verification',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Compare the imported Study Year with the '
                        'automatically calculated year.',
                      ),
                    ],
                  ),
                ),
                Icon(
                  mismatchCount > 0
                      ? Icons.warning_amber_rounded
                      : Icons.verified_outlined,
                  color: mismatchCount > 0
                      ? Colors.orange
                      : Colors.green,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: mismatchCount > 0
                    ? Colors.orange.withValues(alpha: 0.08)
                    : Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    mismatchCount > 0
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: mismatchCount > 0
                        ? Colors.orange.shade800
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mismatchCount > 0
                          ? '$mismatchCount Study Year group(s) have a mismatch.'
                          : 'No Study Year mismatches detected.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final row in _studyYearComparisons)
              _buildStudyYearRow(row),
            const SizedBox(height: 12),
            Text(
              'Calculation: Academic Year start − Admitted Batch '
              'start + 1. This is a standard-entry estimate. '
              'Lateral entry and programme-specific exceptions '
              'may require separate rules.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyYearRow(Map<String, Object?> row) {
    final mismatch = row['isMismatch'] == true;
    final expected = row['expectedStudyYear'] as int?;
    final source = row['sourceStudyYear']?.toString() ?? '';
    final count = row['recordCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: mismatch
              ? Colors.orange.shade300
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${row['admittedBatch']}  →  ${row['academicYear']}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Excel Study Year',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.isEmpty ? 'Missing' : source,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expected Study Year',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expected == null
                          ? 'Cannot calculate'
                          : _ordinal(expected),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$count matching fee record(s)',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (expected == null)
                const Text(
                  'Unable to verify',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  mismatch ? 'Mismatch' : 'Consistent',
                  style: TextStyle(
                    color: mismatch
                        ? Colors.orange.shade800
                        : Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordCount = _summary['recordCount'] ?? 0;
    final sourceTotal = _summary['sourceTotal'] ?? 0;
    final calculatedTotal = _summary['calculatedTotal'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load Fee Explorer:\n$_error'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fee Explorer',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Explore fee structures using seven filters.',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Seven cascading filters.
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Filter fee records',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 18),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns =
                                      constraints.maxWidth > 850 ? 3 : 2;

                                  return GridView.count(
                                    crossAxisCount: columns,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: 3.2,
                                    children: dimensions
                                        .map(_filterDropdown)
                                        .toList(),
                                  );
                                },
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selected.clear();
                                    });
                                    _refresh();
                                  },
                                  icon: const Icon(Icons.restart_alt),
                                  label: const Text('Clear all filters'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Summary cards.
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              'Matching fee records',
                              '$recordCount',
                              Icons.receipt_long_outlined,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _statCard(
                              'Calculated fee total',
                              _rupees(calculatedTotal),
                              Icons.currency_rupee,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Fee breakdown.
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fee Breakdown',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildFeeBreakdown(),
                              const Divider(height: 28),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Calculated Grand Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _rupees(calculatedTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Source Total Fee'),
                                  ),
                                  Text(
                                    _rupees(sourceTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Source total is shown for comparison. '
                                'It is not added again to the fee components.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Study Year verification.
                      _buildStudyYearVerification(),
                    ],
                  ),
                ),
    );
  }
}
