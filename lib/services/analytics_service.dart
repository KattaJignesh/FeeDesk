import '../core/database/database_service.dart';

class AnalyticsService {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<Map<String, dynamic>> getOverview() async {
    final db = await _dbService.database;

    final result = await db.rawQuery('''
      SELECT
        COUNT(f.id) AS record_count,
        COALESCE(SUM(f.source_total_paise), 0) AS total_fee_paise,
        COUNT(DISTINCT f.school) AS school_count,
        COUNT(DISTINCT f.program) AS program_count,
        COUNT(DISTINCT f.degree) AS degree_count
      FROM fee_records f
      INNER JOIN dataset_imports d ON d.id = f.import_id
      WHERE d.status = 'active'
    ''');

    return result.first;
  }

  Future<List<Map<String, dynamic>>> getFeeByDimension(String dimension) async {
    const allowedDimensions = {
      'School': 'school',
      'Program': 'program',
      'Degree': 'degree',
      'Study Year': 'study_year',
      'CQ/MQ': 'quota',
    };

    final column = allowedDimensions[dimension];

    if (column == null) {
      throw ArgumentError('Unsupported analytics dimension: $dimension');
    }

    final db = await _dbService.database;

    return db.rawQuery('''
      SELECT
        COALESCE(NULLIF(TRIM(f.$column), ''), 'Unspecified') AS label,
        COUNT(f.id) AS record_count,
        COALESCE(SUM(f.source_total_paise), 0) AS total_paise
      FROM fee_records f
      INNER JOIN dataset_imports d ON d.id = f.import_id
      WHERE d.status = 'active'
      GROUP BY COALESCE(NULLIF(TRIM(f.$column), ''), 'Unspecified')
      ORDER BY total_paise DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getCategoryBreakdown() async {
    final db = await _dbService.database;

    return db.rawQuery('''
      SELECT
        c.name AS label,
        COALESCE(SUM(e.amount_paise), 0) AS total_paise
      FROM expenditure_items e
      INNER JOIN fee_records f ON f.id = e.fee_record_id
      INNER JOIN dataset_imports d ON d.id = f.import_id
      INNER JOIN expenditure_categories c ON c.id = e.category_id
      WHERE d.status = 'active'
      GROUP BY c.id, c.name
      ORDER BY total_paise DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getRecentImports() async {
    final db = await _dbService.database;

    return db.rawQuery('''
      SELECT
        file_name,
        imported_at,
        version_number,
        accepted_rows
      FROM dataset_imports
      WHERE status = 'active'
      ORDER BY imported_at DESC
      LIMIT 5
    ''');
  }
}
