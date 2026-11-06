
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;

    // Windows uses SQLite through FFI.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Store the database in the device's private application folder.
    final directory = await getApplicationSupportDirectory();

    await directory.create(recursive: true);

    final databasePath = p.join(
      directory.path,
      'mbu_fee_manager.db',
    );

    _database = await openDatabase(
      databasePath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDatabase,
    );

    debugPrint('MBU Database initialized: $databasePath');
  }

  Future<Database> get database async {
    if (_database == null) {
      await initialize();
    }

    return _database!;
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE dataset_imports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        version_number INTEGER NOT NULL,
        import_mode TEXT NOT NULL DEFAULT 'full',
        total_rows INTEGER NOT NULL DEFAULT 0,
        accepted_rows INTEGER NOT NULL DEFAULT 0,
        rejected_rows INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE fee_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        import_id INTEGER NOT NULL,

        admitted_batch TEXT NOT NULL,
        academic_year TEXT NOT NULL,
        school TEXT NOT NULL,
        degree TEXT NOT NULL,
        program TEXT NOT NULL,
        study_year TEXT NOT NULL,
        quota TEXT NOT NULL,

        source_total_paise INTEGER,
        source_sheet TEXT,
        source_row INTEGER,

        FOREIGN KEY (import_id)
          REFERENCES dataset_imports(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expenditure_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenditure_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fee_record_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        amount_paise INTEGER NOT NULL,
        original_column TEXT,

        FOREIGN KEY (fee_record_id)
          REFERENCES fee_records(id)
          ON DELETE CASCADE,

        FOREIGN KEY (category_id)
          REFERENCES expenditure_categories(id),

        UNIQUE (fee_record_id, category_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE import_errors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        import_id INTEGER NOT NULL,
        source_row INTEGER,
        column_name TEXT,
        error_type TEXT NOT NULL,
        message TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'warning',

        FOREIGN KEY (import_id)
          REFERENCES dataset_imports(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');

    // Indexes for fast filtering and searching.
    await db.execute('''
      CREATE INDEX idx_fee_import
      ON fee_records(import_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_fee_dimensions
      ON fee_records(
        admitted_batch,
        academic_year,
        school,
        degree,
        program,
        study_year,
        quota
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_expenditure_record
      ON expenditure_items(fee_record_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_expenditure_category
      ON expenditure_items(category_id)
    ''');

    debugPrint('All database tables created successfully.');
  }

  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final records = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM fee_records'),
        ) ??
        0;

    final categories = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM expenditure_categories',
          ),
        ) ??
        0;

    final imports = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM dataset_imports'),
        ) ??
        0;

    return {
      'records': records,
      'categories': categories,
      'imports': imports,
    };
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
