import 'package:sqflite/sqflite.dart';

import '../core/database/database_service.dart';
import 'column_mapping_service.dart';
import 'excel_import_service.dart';

class ImportSummary {
  final int importId;
  final int versionNumber;
  final int importedRows;
  final int expenditureItems;
  final int categories;

  const ImportSummary({
    required this.importId,
    required this.versionNumber,
    required this.importedRows,
    required this.expenditureItems,
    required this.categories,
  });
}

class ImportService {
  ImportService({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  final DatabaseService _databaseService;

  static const List<String> _dimensions = [
    'Admitted Batch',
    'Academic Year',
    'School',
    'Degree',
    'Program',
    'Study Year',
    'CQ/MQ',
  ];

  Future<ImportSummary> importCompleteWorkbook({
    required String fileName,
    required SheetPreview sheet,
    required ColumnMappingResult mapping,
  }) async {
    if (!mapping.isValid) {
      throw Exception(
        'Cannot import: required dimension mappings are incomplete.',
      );
    }

    if (mapping.expenditureColumns.isEmpty) {
      throw Exception('Cannot import: no expenditure columns were detected.');
    }

    // Ensure every required dimension has a distinct Excel column.
    final mappedIndexes = _dimensions.map((dimension) {
      return _findDimensionColumn(mapping, dimension);
    }).toList();

    if (mappedIndexes.any((index) => index == null)) {
      throw Exception(
        'Cannot import: one or more required dimensions are unmapped.',
      );
    }

    if (mappedIndexes.toSet().length != _dimensions.length) {
      throw Exception(
        'Cannot import: multiple dimensions use the same Excel column.',
      );
    }

    if (sheet.dataRows.isEmpty) {
      throw Exception('Cannot import an empty workbook.');
    }

    final db = await _databaseService.database;

    return db.transaction<ImportSummary>((txn) async {
      // Generate the next version number.
      final versionResult = await txn.rawQuery(
        'SELECT COALESCE(MAX(version_number), 0) + 1 AS next_version '
        'FROM dataset_imports',
      );

      final versionNumber = (versionResult.first['next_version'] as int?) ?? 1;

      final importedAt = DateTime.now().toIso8601String();

      // Create the new import version.
      final importId = await txn.insert('dataset_imports', {
        'file_name': fileName,
        'imported_at': importedAt,
        'version_number': versionNumber,
        'import_mode': 'full',
        'total_rows': sheet.dataRows.length,
        'accepted_rows': 0,
        'rejected_rows': 0,
        'status': 'pending',
      });

      int importedRows = 0;
      int expenditureItems = 0;
      final categoryIds = <String, int>{};

      for (int rowIndex = 0; rowIndex < sheet.dataRows.length; rowIndex++) {
        final row = sheet.dataRows[rowIndex];

        // Read the seven required dimensions.
        final dimensionValues = <String, String>{};

        for (final dimension in _dimensions) {
          final columnIndex = _findDimensionColumn(mapping, dimension)!;

          final value = columnIndex < row.length ? row[columnIndex].trim() : '';

          if (value.isEmpty) {
            throw Exception(
              'Missing $dimension in Excel row '
              '${sheet.headerRowNumber + rowIndex + 1}.',
            );
          }

          dimensionValues[dimension] = value;
        }

        // Read the original source total, if available.
        int? sourceTotalPaise;

        final totalColumn = mapping.sourceTotalColumn;

        if (totalColumn != null && totalColumn < row.length) {
          final totalValue = row[totalColumn].trim();

          if (totalValue.isNotEmpty) {
            sourceTotalPaise = _parseAmount(totalValue);

            if (sourceTotalPaise == null || sourceTotalPaise < 0) {
              throw Exception(
                'Invalid source Total Fee in Excel row '
                '${sheet.headerRowNumber + rowIndex + 1}.',
              );
            }
          }
        }

        // Create the fee record.
        final feeRecordId = await txn.insert('fee_records', {
          'import_id': importId,
          'admitted_batch': dimensionValues['Admitted Batch'],
          'academic_year': dimensionValues['Academic Year'],
          'school': dimensionValues['School'],
          'degree': dimensionValues['Degree'],
          'program': dimensionValues['Program'],
          'study_year': dimensionValues['Study Year'],
          'quota': dimensionValues['CQ/MQ'],
          'source_total_paise': sourceTotalPaise,
          'source_sheet': sheet.sheetName,
          'source_row': sheet.headerRowNumber + rowIndex + 1,
        });

        // Save every expenditure component separately.
        for (final columnIndex in mapping.expenditureColumns) {
          if (columnIndex >= row.length) continue;

          final amountText = row[columnIndex].trim();

          // Blank fee values remain missing, not zero.
          if (amountText.isEmpty) continue;

          final amountPaise = _parseAmount(amountText);

          if (amountPaise == null || amountPaise < 0) {
            throw Exception(
              'Invalid fee amount in Excel row '
              '${sheet.headerRowNumber + rowIndex + 1}, '
              'column ${sheet.headers[columnIndex]}.',
            );
          }

          final categoryName = sheet.headers[columnIndex].trim();

          if (categoryName.isEmpty) {
            throw Exception('An expenditure column has an empty header.');
          }

          int? categoryId = categoryIds[categoryName];

          if (categoryId == null) {
            await txn.insert('expenditure_categories', {
              'name': categoryName,
              'is_active': 1,
              'created_at': importedAt,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);

            final categoryResult = await txn.query(
              'expenditure_categories',
              columns: ['id'],
              where: 'name = ?',
              whereArgs: [categoryName],
              limit: 1,
            );

            if (categoryResult.isEmpty) {
              throw Exception(
                'Could not create expenditure category: $categoryName',
              );
            }

            categoryId = categoryResult.first['id'] as int;
            categoryIds[categoryName] = categoryId;
          }

          await txn.insert('expenditure_items', {
            'fee_record_id': feeRecordId,
            'category_id': categoryId,
            'amount_paise': amountPaise,
            'original_column': categoryName,
          });

          expenditureItems++;
        }

        importedRows++;
      }

      // Only after all rows have been saved successfully,
      // archive the previous active version.
      await txn.update('dataset_imports', {
        'status': 'archived',
      }, where: "status = 'active'");

      // Activate the new version.
      await txn.update(
        'dataset_imports',
        {'accepted_rows': importedRows, 'status': 'active'},
        where: 'id = ?',
        whereArgs: [importId],
      );

      // Write an audit entry.
      await txn.insert('audit_logs', {
        'action': 'FULL_IMPORT',
        'description':
            'Imported $importedRows records from $fileName '
            'as version $versionNumber.',
        'created_at': importedAt,
      });

      return ImportSummary(
        importId: importId,
        versionNumber: versionNumber,
        importedRows: importedRows,
        expenditureItems: expenditureItems,
        categories: categoryIds.length,
      );
    });
  }

  int? _findDimensionColumn(ColumnMappingResult mapping, String dimension) {
    for (final entry in mapping.dimensionColumns.entries) {
      if (_normalize(entry.key) == _normalize(dimension)) {
        return entry.value;
      }
    }

    return null;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // Converts rupees into integer paise.
  // Correctly handles negative values, including -0.50.
  int? _parseAmount(String input) {
    var value = input.trim();

    value = value.replaceAll('₹', '');
    value = value.replaceAll(',', '');
    value = value.replaceAll(RegExp(r'\s+'), '');

    if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(value)) {
      return null;
    }

    final isNegative = value.startsWith('-');
    final unsignedValue = isNegative ? value.substring(1) : value;

    final parts = unsignedValue.split('.');
    final rupees = int.tryParse(parts[0]);

    if (rupees == null) return null;

    final paise = parts.length == 2
        ? int.tryParse(parts[1].padRight(2, '0'))
        : 0;

    if (paise == null) return null;

    final totalPaise = rupees * 100 + paise;

    return isNegative ? -totalPaise : totalPaise;
  }
}
