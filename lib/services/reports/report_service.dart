import '../../core/database/database_service.dart';

class ReportService {
  final DatabaseService _databaseService = DatabaseService.instance;

  // The seven supported report dimensions.
  static const Map<String, String> dimensions = {
    'Admitted Batch': 'admitted_batch',
    'Academic Year': 'academic_year',
    'School': 'school',
    'Degree': 'degree',
    'Program': 'program',
    'Study Year': 'study_year',
    'CQ/MQ': 'quota',
  };

  // Build safe SQL conditions from selected filters.
  Map<String, dynamic> _buildConditions(
    Map<String, String?> filters, {
    String? excludeDimension,
  }) {
    final conditions = <String>[];
    final arguments = <Object?>[];

    for (final entry in dimensions.entries) {
      if (entry.key == excludeDimension) continue;

      final value = filters[entry.key];

      if (value != null && value.isNotEmpty && value != 'All') {
        conditions.add('f.${entry.value} = ?');
        arguments.add(value);
      }
    }

    return {
      'where': conditions.isEmpty ? '' : ' AND ${conditions.join(' AND ')}',
      'arguments': arguments,
    };
  }

  // Get options for a filter, respecting all other selected filters.
  Future<List<String>> getFilterOptions(
    String dimension,
    Map<String, String?> filters,
  ) async {
    final column = dimensions[dimension];

    if (column == null) {
      throw ArgumentError('Unknown report dimension: $dimension');
    }

    final db = await _databaseService.database;

    final conditions = _buildConditions(filters, excludeDimension: dimension);

    final rows = await db.rawQuery('''
      SELECT DISTINCT f.$column AS option_value
      FROM fee_records f
      INNER JOIN dataset_imports d ON d.id = f.import_id
      WHERE d.status = 'active'
        AND f.$column IS NOT NULL
        AND TRIM(f.$column) != ''
        ${conditions['where']}
      ORDER BY f.$column COLLATE NOCASE
      ''', conditions['arguments'] as List<Object?>);

    return rows.map((row) => row['option_value'].toString()).toList();
  }

  // Fetch filtered report records and their expenditure categories.
  Future<Map<String, dynamic>> getReportData({
    Map<String, String?> filters = const {},
  }) async {
    final db = await _databaseService.database;

    final conditions = _buildConditions(filters);

    final records = await db.rawQuery('''
      SELECT f.*
      FROM fee_records f
      INNER JOIN dataset_imports d ON d.id = f.import_id
      WHERE d.status = 'active'
        ${conditions['where']}
      ORDER BY f.id
      ''', conditions['arguments'] as List<Object?>);

    final recordIds = records.map((record) => record['id'] as int).toList();

    List<Map<String, Object?>> categories = [];

    if (recordIds.isNotEmpty) {
      final placeholders = List.filled(recordIds.length, '?').join(',');

      categories = await db.rawQuery('''
        SELECT DISTINCT c.name
        FROM expenditure_categories c
        INNER JOIN expenditure_items e ON e.category_id = c.id
        WHERE e.fee_record_id IN ($placeholders)
        ORDER BY c.name COLLATE NOCASE
        ''', recordIds);
    }

    final categoryNames = categories
        .map((row) => row['name'].toString())
        .toList();

    final reportRecords = <Map<String, dynamic>>[];

    for (final record in records) {
      final items = await db.rawQuery(
        '''
        SELECT c.name, e.amount_paise
        FROM expenditure_items e
        INNER JOIN expenditure_categories c ON c.id = e.category_id
        WHERE e.fee_record_id = ?
        ''',
        [record['id']],
      );

      final amounts = <String, int>{
        for (final category in categoryNames) category: 0,
      };

      for (final item in items) {
        final name = item['name'].toString();

        amounts[name] =
            (amounts[name] ?? 0) +
            ((item['amount_paise'] as num?)?.toInt() ?? 0);
      }

      final calculatedTotal = amounts.values.fold<int>(
        0,
        (sum, amount) => sum + amount,
      );

      reportRecords.add({
        ...record,
        'category_amounts': amounts,
        'calculated_total_paise': calculatedTotal,
      });
    }

    final totalSourcePaise = reportRecords.fold<int>(
      0,
      (sum, record) =>
          sum + ((record['source_total_paise'] as num?)?.toInt() ?? 0),
    );

    final totalCalculatedPaise = reportRecords.fold<int>(
      0,
      (sum, record) => sum + (record['calculated_total_paise'] as int),
    );

    return {
      'categories': categoryNames,
      'records': reportRecords,
      'record_count': reportRecords.length,
      'source_total_paise': totalSourcePaise,
      'calculated_total_paise': totalCalculatedPaise,
      'filters': filters,
    };
  }
}
