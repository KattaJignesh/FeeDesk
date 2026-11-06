import 'package:excel/excel.dart';

class SheetPreview {
  final String sheetName;
  final int headerRowNumber;
  final List<String> headers;
  final List<List<String>> sampleRows;
  final List<List<String>> dataRows;
  final int totalRows;

  const SheetPreview({
    required this.sheetName,
    required this.headerRowNumber,
    required this.headers,
    required this.sampleRows,
    required this.dataRows,
    required this.totalRows,
  });
}

class WorkbookPreview {
  final List<SheetPreview> sheets;

  const WorkbookPreview({required this.sheets});
}

class ExcelImportService {
  WorkbookPreview inspectWorkbook(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final previews = <SheetPreview>[];

    for (final entry in workbook.tables.entries) {
      final sheetName = entry.key;
      final sheet = entry.value;
      final rows = sheet.rows;

      if (rows.isEmpty) continue;

      // Find the first non-empty row as the header.
      int headerIndex = -1;

      for (int i = 0; i < rows.length; i++) {
        final hasContent = rows[i].any(
          (cell) => cell?.value?.toString().trim().isNotEmpty == true,
        );

        if (hasContent) {
          headerIndex = i;
          break;
        }
      }

      if (headerIndex == -1) continue;

      final headers = rows[headerIndex].map((cell) {
        return cell?.value?.toString().trim() ?? '';
      }).toList();

      // Retain every non-empty data row.
      final dataRows = rows
          .skip(headerIndex + 1)
          .where((row) {
            return row.any(
              (cell) => cell?.value?.toString().trim().isNotEmpty == true,
            );
          })
          .map((row) {
            return List.generate(headers.length, (index) {
              if (index >= row.length) return '';
              return row[index]?.value?.toString().trim() ?? '';
            });
          })
          .toList();

      final sampleRows = dataRows.take(5).toList();

      previews.add(
        SheetPreview(
          sheetName: sheetName,
          headerRowNumber: headerIndex + 1,
          headers: headers,
          sampleRows: sampleRows,
          dataRows: dataRows,
          totalRows: dataRows.length,
        ),
      );
    }

    return WorkbookPreview(sheets: previews);
  }
}
