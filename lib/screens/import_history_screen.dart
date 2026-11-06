import 'package:flutter/material.dart';

import '../services/import_history_service.dart';
import 'data_import/excel_import_screen.dart';
import 'fee_explorer/fee_explorer_screen.dart';

class ImportHistoryScreen extends StatefulWidget {
  const ImportHistoryScreen({super.key});

  @override
  State<ImportHistoryScreen> createState() => _ImportHistoryScreenState();
}

class _ImportHistoryScreenState extends State<ImportHistoryScreen> {
  final ImportHistoryService _service = ImportHistoryService();

  List<Map<String, Object?>> _imports = [];

  Map<String, int> _stats = {'imports': 0, 'records': 0};

  bool _loading = true;
  String? _error;

  static const Color _blue = Color(0xFF3157D5);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _text = Color(0xFF17233D);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final imports = await _service.getImportHistory();
      final stats = await _service.getHistoryStats();

      if (!mounted) return;

      setState(() {
        _imports = imports;
        _stats = stats;
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

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  void _goHome() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _navigateTo(Widget screen) {
    Navigator.pop(context);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
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
              padding: const EdgeInsets.all(22),
              color: const Color(0xFFEEF2FF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'FeeDesk',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Offline Fee Management',
                    style: TextStyle(color: Color(0xFF788397), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _drawerItem(
              icon: Icons.home_rounded,
              title: 'Home',
              onTap: _goHome,
            ),
            _drawerItem(
              icon: Icons.upload_file_rounded,
              title: 'Upload File',
              onTap: () => _navigateTo(const ExcelImportScreen()),
            ),
            _drawerItem(
              icon: Icons.manage_search_rounded,
              title: 'Fee Explorer',
              onTap: () => _navigateTo(const FeeExplorerScreen()),
            ),
            _drawerItem(
              icon: Icons.history_rounded,
              title: 'Import History',
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'FeeDesk 2.0',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        selected: selected,
        selectedTileColor: const Color(0xFFEEF2FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        leading: Icon(icon, color: selected ? _blue : const Color(0xFF667085)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _blue : _text,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _restoreImport(Map<String, Object?> item) async {
    final id = item['id'];
    final version = item['version_number'];

    if (id is! num) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this version?'),
        content: Text(
          'This will make import version $version active. '
          'The currently active version will be archived.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.rollbackToVersion(id.toInt());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import version restored successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadHistory();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(Object? value) {
    if (value == null) return 'Date unavailable';

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/${date.year}  $hour:$minute';
    } catch (_) {
      return value.toString();
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'archived':
        return Colors.blueGrey;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE5EAF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _blue, size: 25),
            const SizedBox(height: 13),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(color: Color(0xFF788397), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard(Map<String, Object?> item) {
    final status = (item['status'] ?? 'unknown').toString();
    final version = item['version_number'] ?? '-';
    final fileName = item['file_name'] ?? 'Unknown file';
    final records = item['actual_records'] ?? 0;
    final importedAt = _formatDate(item['imported_at']);

    final isActive = status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Import Version $version',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          _detailRow(Icons.description_outlined, fileName.toString()),
          const SizedBox(height: 10),
          _detailRow(Icons.table_rows_outlined, '$records fee records'),
          const SizedBox(height: 10),
          _detailRow(Icons.calendar_today_outlined, importedAt),
          if (!isActive && status.toLowerCase() == 'archived') ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _restoreImport(item),
                icon: const Icon(Icons.restore),
                label: const Text('Restore version'),
                style: OutlinedButton.styleFrom(foregroundColor: _blue),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF788397)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF424B5D), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 45, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Could not load import history.\n$_error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _loadHistory, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_imports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 55, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No import history yet.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 5),
            Text(
              'Your imported datasets will appear here.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _imports.length,
      itemBuilder: (context, index) {
        return _buildImportCard(_imports[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top navigation bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5EAF2))),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: _text,
                  ),
                  Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Open navigation menu',
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                      icon: const Icon(Icons.menu_rounded),
                      color: _text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'FeeDesk',
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh history',
                    onPressed: _loadHistory,
                    icon: const Icon(Icons.refresh_rounded),
                    color: _blue,
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Import History',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'View previous datasets and restore older versions.',
                          style: TextStyle(
                            color: Color(0xFF788397),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Statistics
                        Row(
                          children: [
                            _statCard(
                              'Total imports',
                              '${_stats['imports'] ?? 0}',
                              Icons.history_rounded,
                            ),
                            const SizedBox(width: 14),
                            _statCard(
                              'Total imported records',
                              '${_stats['records'] ?? 0}',
                              Icons.dataset_outlined,
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        Expanded(child: _buildContent()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
