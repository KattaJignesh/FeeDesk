
import 'column_mapping_service.dart';
import 'excel_import_service.dart';

enum ValidationSeverity {
  error,
  warning,
}

class ValidationIssue {
  final int rowNumber;
  final String column;
  final String message;
  final ValidationSeverity severity;

  const ValidationIssue({
    required this.rowNumber,
    required this.column,
    required this.message,
    required this.severity,
  });
}

class ValidationResult {
  final List<ValidationIssue> issues;
  final int totalRows;

  const ValidationResult({
    required this.issues,
    required this.totalRows,
  });

  int get errorCount => issues
      .where((issue) => issue.severity == ValidationSeverity.error)
      .length;

  int get warningCount => issues
      .where((issue) => issue.severity == ValidationSeverity.warning)
      .length;

  bool get canImport => errorCount == 0;
}

class ExcelValidationService {
  ValidationResult validate({
    required SheetPreview sheet,
    required ColumnMappingResult mapping,
  }) {
    final issues = <ValidationIssue>[];
    final rows = sheet.dataRows;

    // 1. Check for missing required dimension mappings.
    if (!mapping.isValid) {
      for (final dimension in mapping.missingDimensions) {
        issues.add(
          ValidationIssue(
            rowNumber: sheet.headerRowNumber,
            column: dimension,
            message: 'Required dimension column is not mapped.',
            severity: ValidationSeverity.error,
          ),
        );
      }
    }

    // 2. Check whether multiple dimensions use the same Excel column.
    final usedColumns = <int, List<String>>{};

    for (final entry in mapping.dimensionColumns.entries) {
      usedColumns.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    for (final entry in usedColumns.entries) {
      if (entry.value.length > 1) {
        issues.add(
          ValidationIssue(
            rowNumber: sheet.headerRowNumber,
            column: 'Column mapping',
            message:
                '${entry.value.join(' and ')} are mapped to the same Excel column. '
                'Each required dimension must use a different column.',
            severity: ValidationSeverity.error,
          ),
        );
      }
    }

    // Stop row validation if the dimension mapping is incomplete or duplicated.
    if (!mapping.isValid ||
        usedColumns.values.any((dimensions) => dimensions.length > 1)) {
      return ValidationResult(
        issues: issues,
        totalRows: rows.length,
      );
    }

    // 3. Check for expenditure columns.
    if (mapping.expenditureColumns.isEmpty) {
      issues.add(
        ValidationIssue(
          rowNumber: sheet.headerRowNumber,
          column: 'Fee columns',
          message: 'No expenditure columns were detected.',
          severity: ValidationSeverity.error,
        ),
      );

      return ValidationResult(
        issues: issues,
        totalRows: rows.length,
      );
    }

    // 4. Detect exact duplicate rows, not merely matching dimensions.
    final seenRecords = <String>{};

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];

      final sourceRowNumber =
          sheet.headerRowNumber + rowIndex + 1;

      final recordKey = row.join('\u001F');

      if (!seenRecords.add(recordKey)) {
        issues.add(
          ValidationIssue(
            rowNumber: sourceRowNumber,
            column: 'Duplicate record',
            message: 'This row is an exact duplicate of an earlier row.',
            severity: ValidationSeverity.error,
          ),
        );
      }

      // Validate the seven required dimensions.
      for (final entry in mapping.dimensionColumns.entries) {
        final columnIndex = entry.value;

        final value = columnIndex < row.length
            ? row[columnIndex].trim()
            : '';

        if (value.isEmpty) {
          issues.add(
            ValidationIssue(
              rowNumber: sourceRowNumber,
              column: entry.key,
              message: 'Required value is missing.',
              severity: ValidationSeverity.error,
            ),
          );
        }
      }

      // Validate expenditure values.
      int calculatedTotalPaise = 0;
      bool allFeesValid = true;

      for (final columnIndex in mapping.expenditureColumns) {
        final columnName = columnIndex < sheet.headers.length
            ? sheet.headers[columnIndex]
            : 'Unknown fee';

        final value = columnIndex < row.length
            ? row[columnIndex].trim()
            : '';

        if (value.isEmpty) {
          issues.add(
            ValidationIssue(
              rowNumber: sourceRowNumber,
              column: columnName,
              message: 'Fee amount is blank.',
              severity: ValidationSeverity.warning,
            ),
          );

          allFeesValid = false;
          continue;
        }

        final amount = _parseAmount(value);

        if (amount == null) {
          issues.add(
            ValidationIssue(
              rowNumber: sourceRowNumber,
              column: columnName,
              message: 'Fee amount is not a valid number.',
              severity: ValidationSeverity.error,
            ),
          );

          allFeesValid = false;
          continue;
        }

        if (amount < 0) {
          issues.add(
            ValidationIssue(
              rowNumber: sourceRowNumber,
              column: columnName,
              message: 'Fee amount cannot be negative.',
              severity: ValidationSeverity.error,
            ),
          );

          allFeesValid = false;
          continue;
        }

        calculatedTotalPaise += amount;
      }

      // Compare component total with the source Total Fee.
      final totalColumn = mapping.sourceTotalColumn;

      if (totalColumn != null && allFeesValid) {
        final sourceValue = totalColumn < row.length
            ? row[totalColumn].trim()
            : '';

        if (sourceValue.isEmpty) {
          issues.add(
            ValidationIssue(
              rowNumber: sourceRowNumber,
              column: 'Total Fee',
              message: 'Source total is blank.',
              severity: ValidationSeverity.warning,
            ),
          );
        } else {
          final sourceTotal = _parseAmount(sourceValue);

          if (sourceTotal == null || sourceTotal < 0) {
            issues.add(
              ValidationIssue(
                rowNumber: sourceRowNumber,
                column: 'Total Fee',
                message: 'Source total is invalid.',
                severity: ValidationSeverity.error,
              ),
            );
          } else if (sourceTotal != calculatedTotalPaise) {
            issues.add(
              ValidationIssue(
                rowNumber: sourceRowNumber,
                column: 'Total Fee',
                message:
                    'Source total does not match the sum of fee components.',
                severity: ValidationSeverity.warning,
              ),
            );
          }
        }
      }
    }

    return ValidationResult(
      issues: issues,
      totalRows: rows.length,
    );
  }

  // Converts rupees into integer paise.
  // Supports 30000, 30,000, ₹30,000 and 30000.50.
  int? _parseAmount(String input) {
    var value = input.trim();

    value = value.replaceAll('₹', '');
    value = value.replaceAll(',', '');
    value = value.replaceAll(RegExp(r'\s+'), '');

    if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(value)) {
      return null;
    }

    final parts = value.split('.');
    final rupees = int.tryParse(parts[0]);

    if (rupees == null) return null;

    final paise = parts.length == 2
        ? int.parse(parts[1].padRight(2, '0'))
        : 0;

    return rupees * 100 + (rupees < 0 ? -paise : paise);
  }
}
