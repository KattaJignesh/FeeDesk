import 'package:flutter/material.dart';

import '../../services/fee_explorer_service.dart';

/// Edit these to match the routes registered in your MaterialApp.
class _Routes {
  static const home = '/home';
  static const upload = '/upload';
  static const history = '/history';
}

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
  bool _initialized = false;
  String? _error;
  int _requestId = 0;

  static const Color _navy = Color(0xFF17345C);
  static const Color _pageBackground = Color(0xFFF5F7FB);
  static const Color _borderColor = Color(0xFFD6DCE7);

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

  bool get _allFiltersSelected {
    return dimensions.every((dimension) {
      final value = _selected[dimension];
      return value != null && value.isNotEmpty;
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    final requestId = ++_requestId;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final newOptions = <String, List<String>>{};

      for (var i = 0; i < dimensions.length; i++) {
        final dimension = dimensions[i];
        final previousFilters = <String, String>{};

        var previousSelectionsComplete = true;

        // Build filters using all preceding dimensions.
        for (var j = 0; j < i; j++) {
          final previous = dimensions[j];
          final value = _selected[previous];

          if (value == null || value.isEmpty) {
            previousSelectionsComplete = false;
            break;
          }

          previousFilters[previous] = value;
        }

        // Do not load later options until previous dimensions are selected.
        if (!previousSelectionsComplete) {
          newOptions[dimension] = [];
          _selected[dimension] = null;
          continue;
        }

        final values = await _service.getOptions(dimension, previousFilters);

        // A newer request has started; discard this one.
        if (requestId != _requestId) return;

        newOptions[dimension] = values;

        // Clear selections that are no longer valid.
        if (_selected[dimension] != null &&
            !values.contains(_selected[dimension])) {
          _selected[dimension] = null;
        }
      }

      Map<String, Object?> summary = {};
      List<Map<String, Object?>> comparisons = [];

      // Fetch results only after all seven filters are selected.
      if (_allFiltersSelected) {
        summary = await _service.getFeeSummary(_filters);

        comparisons = await _service.getStudyYearComparison(_filters);
      }

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _options
          ..clear()
          ..addAll(newOptions);

        _summary = summary;
        _studyYearComparisons = comparisons;
        _loading = false;
        _initialized = true;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _error = e.toString();
        _loading = false;
        _initialized = true;
      });
    }
  }

  Future<void> _changeSelection(String dimension, String? value) async {
    final index = dimensions.indexOf(dimension);

    setState(() {
      _selected[dimension] = value;

      // Clear all dependent selections.
      for (var i = index + 1; i < dimensions.length; i++) {
        _selected[dimensions[i]] = null;
      }

      // Remove previously displayed results immediately.
      _summary = {};
      _studyYearComparisons = [];
    });

    await _refresh();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selected.clear();
      _summary = {};
      _studyYearComparisons = [];
    });

    await _refresh();
  }

  String _rupees(Object? paise) {
    final value = paise is num ? paise.toInt() : 0;
    final rupees = value / 100;

    return '₹${rupees.toStringAsFixed(2)}';
  }

  // ------------------------------------------------------------
  // NAVIGATION
  // ------------------------------------------------------------

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(_Routes.home, (route) => false);
    }
  }

  void _navigateTo(String route) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        selected: selected,
        selectedTileColor: _navy.withValues(alpha: 0.08),
        selectedColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              color: _navy,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'FeeDesk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Fee management',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _drawerItem(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: () => _navigateTo(_Routes.home),
            ),
            _drawerItem(
              icon: Icons.upload_file_outlined,
              label: 'Upload File',
              onTap: () => _navigateTo(_Routes.upload),
            ),
            _drawerItem(
              icon: Icons.manage_search_outlined,
              label: 'Fee Explorer',
              selected: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            _drawerItem(
              icon: Icons.history,
              label: 'History',
              onTap: () => _navigateTo(_Routes.history),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // RESPONSIVE FILTER DROPDOWNS
  // ------------------------------------------------------------

  Widget _filterDropdown(String dimension) {
    final values = _options[dimension] ?? [];
    final selectedValue = _selected[dimension];
    final index = dimensions.indexOf(dimension);

    final previousSelectionsComplete = dimensions.take(index).every((previous) {
      final value = _selected[previous];
      return value != null && value.isNotEmpty;
    });

    final enabled = values.isNotEmpty && previousSelectionsComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label is outside the outlined field to avoid Android overlap.
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            dimension,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          // Key forces a rebuild when the value/options change, because
          // initialValue is only read when the field state is created.
          key: ValueKey('$dimension|$selectedValue|${values.length}'),
          initialValue: selectedValue,
          isExpanded: true,
          isDense: true,
          menuMaxHeight: 350,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: const TextStyle(fontSize: 14, color: Color(0xFF263449)),
          decoration: InputDecoration(
            hintText: enabled
                ? 'Select $dimension'
                : 'Select previous filters first',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF1F3F7),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _navy, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderColor),
            ),
          ),
          items: values
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (value) => _changeSelection(dimension, value)
              : null,
        ),
      ],
    );
  }

  Widget _buildFilterGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 18.0;
        final width = constraints.maxWidth;

        // Phone = 1 column, tablet = 2 columns, desktop = 3 columns.
        final columns = width >= 950
            ? 3
            : width >= 580
            ? 2
            : 1;

        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 18,
          children: [
            for (final dimension in dimensions)
              SizedBox(width: itemWidth, child: _filterDropdown(dimension)),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // STATISTICS CARD
  // ------------------------------------------------------------

  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borderColor),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _navy, size: 25),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 5),
              Text(title, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FEE BREAKDOWN
  // ------------------------------------------------------------

  Widget _buildFeeBreakdown() {
    final categories = (_summary['categoryTotals'] as Map<String, int>?) ?? {};

    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('No fee components found for this selection.'),
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
                  child: Text(entry.key, style: const TextStyle(fontSize: 15)),
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
  // STUDY YEAR VERIFICATION
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
      return Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('No Study Year comparison data is available.'),
        ),
      );
    }

    final mismatchCount = _studyYearComparisons
        .where((row) => row['isMismatch'] == true)
        .length;

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borderColor),
      ),
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
                          color: _navy,
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
                  color: mismatchCount > 0 ? Colors.orange : Colors.green,
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final row in _studyYearComparisons) _buildStudyYearRow(row),
            const SizedBox(height: 12),
            Text(
              'Calculation: Academic Year start − Admitted Batch '
              'start + 1. This is a standard-entry estimate. '
              'Lateral entry and programme-specific exceptions '
              'may require separate rules.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          color: mismatch ? Colors.orange.shade300 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${row['admittedBatch']}  →  ${row['academicYear']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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

  // ------------------------------------------------------------
  // BODY SECTIONS
  // ------------------------------------------------------------

  Widget _buildHeading() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fee Explorer',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Explore fee structures using seven filters.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFilterCard(bool compact) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter fee records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 20),
            _buildFilterGrid(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Clear all filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    final recordCount = _summary['recordCount'] ?? 0;
    final calculatedTotal = _summary['calculatedTotal'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        final recordsCard = _statCard(
          'Matching fee records',
          '$recordCount',
          Icons.receipt_long_outlined,
        );
        final totalCard = _statCard(
          'Calculated fee total',
          _rupees(calculatedTotal),
          Icons.currency_rupee,
        );

        if (isNarrow) {
          return Column(
            children: [recordsCard, const SizedBox(height: 12), totalCard],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: recordsCard),
            const SizedBox(width: 14),
            Expanded(child: totalCard),
          ],
        );
      },
    );
  }

  Widget _buildFeeBreakdownCard() {
    final sourceTotal = _summary['sourceTotal'] ?? 0;
    final calculatedTotal = _summary['calculatedTotal'] ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fee Breakdown',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: _navy,
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(
                  _rupees(calculatedTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    color: _navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Text('Source Total Fee')),
                Text(
                  _rupees(sourceTotal),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Source total is shown for comparison. '
              'It is not added again to the fee components.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 42,
                color: Colors.indigo.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                'Complete all seven filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select Admitted Batch, Academic Year, '
                'School, Degree, Program, Study Year '
                'and CQ/MQ to view matching fee records.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool compact) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeading(),
          const SizedBox(height: 22),
          _buildFilterCard(compact),
          const SizedBox(height: 22),
          if (_allFiltersSelected) ...[
            _buildStatCards(),
            const SizedBox(height: 20),
            _buildFeeBreakdownCard(),
            const SizedBox(height: 20),
            _buildStudyYearVerification(),
          ] else
            _buildEmptyPrompt(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final compact = MediaQuery.of(context).size.width < 600;

    if (!_initialized && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load Fee Explorer:\n$_error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Thin progress bar for refreshes after the first load.
        SizedBox(
          height: 3,
          child: _loading
              ? const LinearProgressIndicator(minHeight: 3)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildContent(compact)),
      ],
    );
  }

  // ------------------------------------------------------------
  // MAIN BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 600;

    return Theme(
      data: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _navy,
          brightness: Brightness.light,
        ),
      ),
      child: Scaffold(
        backgroundColor: _pageBackground,
        drawer: _buildDrawer(),
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leadingWidth: 104,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              ),
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ],
          ),
          title: const Text(
            'FeeDesk',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _refresh,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 28,
              compact ? 8 : 16,
              compact ? 16 : 28,
              0,
            ),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }
}
