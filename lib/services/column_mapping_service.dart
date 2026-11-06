import 'excel_import_service.dart';

class ColumnMappingResult {
  final Map<String, int> dimensionColumns;
  final List<int> expenditureColumns;
  final int? sourceTotalColumn;
  final List<String> missingDimensions;

  const ColumnMappingResult({
    required this.dimensionColumns,
    required this.expenditureColumns,
    required this.sourceTotalColumn,
    required this.missingDimensions,
  });

  bool get isValid => missingDimensions.isEmpty;

  bool get hasExpenditureColumns => expenditureColumns.isNotEmpty;
}

class ColumnMappingService {
  // Required dimensions and their accepted header variations.
  static const Map<String, List<String>> dimensionAliases = {
    'Admitted Batch': [
      'admitted batch',
      'admission batch',
      'batch',
      'admission year',
    ],
    'Academic Year': ['academic year', 'academic session', 'session'],
    'School': ['school', 'school name', 'faculty'],
    'Degree': ['degree', 'degree name'],
    'Program': [
      'program',
      'programme',
      'program name',
      'programme name',
      'course',
      'course name',
    ],
    'Study Year': ['study year', 'year of study', 'year', 'study year name'],
    'CQ/MQ': [
      'cq/mq',
      'cq mq',
      'quota',
      'category',
      'admission category',
      'seat category',
    ],
  };

  // Headers containing these terms are not expenditure components.
  static const List<String> totalAliases = [
    'total fee',
    'total fees',
    'grand total',
    'total amount',
    'total',
  ];

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _matchesAlias(String header, List<String> aliases) {
    final normalizedHeader = _normalize(header);

    return aliases.any((alias) => normalizedHeader == _normalize(alias));
  }

  ColumnMappingResult detect(SheetPreview sheet) {
    final mappings = <String, int>{};
    final expenditureColumns = <int>[];
    int? sourceTotalColumn;

    // Detect the seven required dimensions.
    for (final dimension in dimensionAliases.entries) {
      for (int i = 0; i < sheet.headers.length; i++) {
        if (_matchesAlias(sheet.headers[i], dimension.value)) {
          mappings[dimension.key] = i;
          break;
        }
      }
    }

    // Identify source total separately.
    for (int i = 0; i < sheet.headers.length; i++) {
      final header = sheet.headers[i].trim();

      if (_matchesAlias(header, totalAliases)) {
        sourceTotalColumn = i;
        break;
      }
    }

    // Detect expenditure columns dynamically.
    for (int i = 0; i < sheet.headers.length; i++) {
      final header = sheet.headers[i].trim();

      if (header.isEmpty) continue;

      final normalized = _normalize(header);

      final isTotal = _matchesAlias(header, totalAliases);

      if (isTotal) continue;

      final looksLikeExpenditure =
          normalized.contains('fee') ||
          normalized.contains('charge') ||
          normalized.contains('levy');

      if (looksLikeExpenditure) {
        expenditureColumns.add(i);
      }
    }

    // Find required dimensions that could not be detected.
    final missingDimensions = dimensionAliases.keys
        .where((dimension) => !mappings.containsKey(dimension))
        .toList();

    return ColumnMappingResult(
      dimensionColumns: mappings,
      expenditureColumns: expenditureColumns,
      sourceTotalColumn: sourceTotalColumn,
      missingDimensions: missingDimensions,
    );
  }
}
