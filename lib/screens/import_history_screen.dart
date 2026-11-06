
import 'package:flutter/material.dart';
import '../services/import_history_service.dart';

class ImportHistoryScreen extends StatefulWidget {
  const ImportHistoryScreen({super.key});

  @override
  State<ImportHistoryScreen> createState() =>
      _ImportHistoryScreenState();
}

class _ImportHistoryScreenState extends State<ImportHistoryScreen> {
  final ImportHistoryService _service = ImportHistoryService();

  List<Map<String, Object?>> _imports = [];
  Map<String, int> _stats = {
    'imports': 0,
    'records': 0,
  };

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

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

  Future<void> _restoreImport(Map<String, Object?> item) async {
    final id = item['id'];
    final version = item['version_number'];

    if (id is! num) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this version?'),
        content: Text(
          'This will make import version $version active. '
          'The currently active version will be archived.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
        ),
      );

      await _loadHistory();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
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
      child: Card(
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
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
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
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName.toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.table_rows_outlined, size: 18),
                const SizedBox(width: 8),
                Text('$records fee records'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 17),
                const SizedBox(width: 8),
                Text(importedAt),
              ],
            ),
            if (!isActive && status.toLowerCase() == 'archived') ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _restoreImport(item),
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore version'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
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
                      'Import History',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'View previous datasets and restore older versions.',
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _statCard(
                'Total imports',
                '${_stats['imports']}',
                Icons.history,
              ),
              const SizedBox(width: 14),
              _statCard(
                'Total imported records',
                '${_stats['records']}',
                Icons.dataset_outlined,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Could not load import history.\n$_error',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _loadHistory,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _imports.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 55,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 12),
                                Text('No import history yet.'),
                                SizedBox(height: 5),
                                Text(
                                  'Your imported datasets will appear here.',
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _imports.length,
                            itemBuilder: (context, index) =>
                                _buildImportCard(_imports[index]),
                          ),
          ),
        ],
      ),
    );
  }
}
