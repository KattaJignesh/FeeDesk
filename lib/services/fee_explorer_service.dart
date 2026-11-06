import '../core/database/database_service.dart';

class FeeExplorerService {
  FeeExplorerService({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  final DatabaseService _databaseService;

  static const Map<String, String> dimensions = {
    'Admitted Batch': 'admitted_batch',
    'Academic Year': 'academic_year',
    'School': 'school',
    'Degree': 'degree',
    'Program': 'program',
    'Study Year': 'study_year',
    'CQ/MQ': 'quota',
  };

  String _whereClause(Map<String, String> filters) {
    return filters.keys.map((key) => '${dimensions[key]} = ?').join(' AND ');
  }

  List<Object?> _whereArgs(Map<String, String> filters) {
    return filters.values.toList();
  }

  Future<List<String>> getOptions(
    String dimension,
    Map<String, String> filters,
  ) async {
    final db = await _databaseService.database;
    final column = dimensions[dimension];

    if (column == null) return [];

    final conditions = [
      "d.status = 'active'",
      'f.$column IS NOT NULL',
      "f.$column != ''",
    ];

    final args = <Object?>[];

    if (filters.isNotEmpty) {
      conditions.add(_whereClause(filters));
      args.addAll(_whereArgs(filters));
    }

    final result = await db.rawQuery('''
      SELECT DISTINCT f.$column AS value
      FROM fee_records f
      INNER JOIN dataset_imports d ON d.id = f.import_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY value
      ''', args);

    return result.map((row) => row['value'].toString()).toList();
  }

  Future<Map<String, Object?>> getFeeSummary(
    Map<String, String> filters,
  ) async {
    final db = await _databaseService.database;

    final conditions = ["d.status = 'active'"];
    final args = <Object?>[];

    if (filters.isNotEmpty) {
      conditions.add(_whereClause(filters));
      args.addAll(_whereArgs(filters));
    }

    final records = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT f.id) AS record_count,
        COALESCE(SUM(f.source_total_paise), 0) AS source_total
      FROM fee_records f
      INNER JOIN dataset_imports d ON d.id = f.import_id
      WHERE ${conditions.join(' AND ')}
      ''', args);

    final categories = await db.rawQuery('''
      SELECT
        c.name AS category,
        COALESCE(SUM(e.amount_paise), 0) AS total_paise
      FROM fee_records f
      INNER JOIN dataset_imports d ON d.id = f.import_id
      INNER JOIN expenditure_items e ON e.fee_record_id = f.id
      INNER JOIN expenditure_categories c ON c.id = e.category_id
      WHERE ${conditions.join(' AND ')}
      GROUP BY c.id, c.name
      ORDER BY c.name
      ''', args);

    final categoryTotals = <String, int>{};
    var calculatedTotal = 0;

    for (final row in categories) {
      final amount = (row['total_paise'] as num).toInt();
      categoryTotals[row['category'].toString()] = amount;
      calculatedTotal += amount;
    }

    return {
      'recordCount': (records.first['record_count'] as num).toInt(),
      'sourceTotal': (records.first['source_total'] as num).toInt(),
      'categoryTotals': categoryTotals,
      'calculatedTotal': calculatedTotal,
    };
  }

  // ------------------------------------------------------------
  // STUDY YEAR VERIFICATION
  // ------------------------------------------------------------

  Future<List<Map<String, Object?>>> getStudyYearComparison(
    Map<String, String> filters,
  ) async {
    final db = await _databaseService.database;

    final conditions = ["d.status = 'active'"];
    final args = <Object?>[];

    // Exclude the Study Year filter so that all source Study Years
    // remain visible for comparison.
    final comparisonFilters = Map<String, String>.from(filters)
      ..remove('Study Year');

    if (comparisonFilters.isNotEmpty) {
      conditions.add(_whereClause(comparisonFilters));
      args.addAll(_whereArgs(comparisonFilters));
    }

    final rows = await db.rawQuery('''
      SELECT
        f.admitted_batch,
        f.academic_year,
        f.study_year,
        COUNT(*) AS record_count
      FROM fee_records f
      INNER JOIN dataset_imports d ON d.id = f.import_id
      WHERE ${conditions.join(' AND ')}
      GROUP BY
        f.admitted_batch,
        f.academic_year,
        f.study_year
      ORDER BY
        f.admitted_batch,
        f.academic_year,
        f.study_year
      ''', args);

    return rows.map((row) {
      final batch = row['admitted_batch']?.toString() ?? '';
      final academicYear = row['academic_year']?.toString() ?? '';
      final sourceStudyYear = row['study_year']?.toString() ?? '';

      final expected = _calculateExpectedStudyYear(batch, academicYear);

      final sourceNumber = _extractStudyYearNumber(sourceStudyYear);

      return {
        'admittedBatch': batch,
        'academicYear': academicYear,
        'sourceStudyYear': sourceStudyYear,
        'expectedStudyYear': expected,
        'recordCount': (row['record_count'] as num).toInt(),
        'isMismatch':
            expected != null &&
            sourceNumber != null &&
            expected != sourceNumber,
      };
    }).toList();
  }

  int? _calculateExpectedStudyYear(String admittedBatch, String academicYear) {
    final batchStart = _extractYear(admittedBatch);
    final academicStart = _extractYear(academicYear);

    if (batchStart == null || academicStart == null) {
      return null;
    }

    final expected = academicStart - batchStart + 1;

    if (expected < 1 || expected > 10) {
      return null;
    }

    return expected;
  }

  int? _extractYear(String value) {
    final match = RegExp(r'\b(19|20)\d{2}\b').firstMatch(value);

    if (match == null) return null;

    return int.tryParse(match.group(0)!);
  }

  int? _extractStudyYearNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);

    if (match == null) return null;

    return int.tryParse(match.group(0)!);
  }
}
