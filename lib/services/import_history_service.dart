import '../core/database/database_service.dart';

class ImportHistoryService {
  ImportHistoryService({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  final DatabaseService _databaseService;

  // Fetch all import versions, newest first.
  Future<List<Map<String, Object?>>> getImportHistory() async {
    final db = await _databaseService.database;

    return db.rawQuery('''
      SELECT
        d.*,
        (
          SELECT COUNT(*)
          FROM fee_records f
          WHERE f.import_id = d.id
        ) AS actual_records
      FROM dataset_imports d
      ORDER BY d.version_number DESC
    ''');
  }

  // Fetch the currently active import.
  Future<Map<String, Object?>?> getActiveImport() async {
    final db = await _databaseService.database;

    final results = await db.query(
      'dataset_imports',
      where: "status = 'active'",
      limit: 1,
    );

    return results.isEmpty ? null : results.first;
  }

  // Restore a previously imported dataset version.
  Future<void> rollbackToVersion(int importId) async {
    final db = await _databaseService.database;

    await db.transaction((txn) async {
      final target = await txn.query(
        'dataset_imports',
        where: 'id = ?',
        whereArgs: [importId],
        limit: 1,
      );

      if (target.isEmpty) {
        throw Exception('Selected import version was not found.');
      }

      final status = target.first['status'];

      if (status == 'pending') {
        throw Exception('Cannot restore an incomplete import.');
      }

      final versionNumber = target.first['version_number'];

      // Archive the currently active version.
      await txn.update('dataset_imports', {
        'status': 'archived',
      }, where: "status = 'active'");

      // Activate the selected version.
      await txn.update(
        'dataset_imports',
        {'status': 'active'},
        where: 'id = ?',
        whereArgs: [importId],
      );

      // Record the rollback in the audit log.
      await txn.insert('audit_logs', {
        'action': 'ROLLBACK',
        'description': 'Restored dataset import version $versionNumber.',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  // Get import history statistics.
  Future<Map<String, int>> getHistoryStats() async {
    final db = await _databaseService.database;

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_imports,
        COALESCE(SUM(accepted_rows), 0) AS total_records
      FROM dataset_imports
      WHERE status IN ('active', 'archived')
    ''');

    return {
      'imports': (result.first['total_imports'] as num).toInt(),
      'records': (result.first['total_records'] as num).toInt(),
    };
  }
}
