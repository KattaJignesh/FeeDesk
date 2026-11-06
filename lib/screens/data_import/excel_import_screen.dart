import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../fee_explorer/fee_explorer_screen.dart';
import '../import_history_screen.dart';
import '../../services/excel_import_service.dart';
import '../../services/column_mapping_service.dart';
import '../../services/excel_validation_service.dart';
import '../../services/import_service.dart';

import 'column_mapping_editor.dart';
import 'validation_report_panel.dart';

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final ExcelImportService _service = ExcelImportService();
  final ColumnMappingService _mappingService = ColumnMappingService();
  final ExcelValidationService _validationService = ExcelValidationService();
  final ImportService _importService = ImportService();

  final Map<String, Map<String, int?>> _manualMappings = {};

  WorkbookPreview? _preview;
  String? _fileName;
  String? _error;
  String? _importMessage;

  bool _loading = false;
  bool _importing = false;

  static const Color brandBlue = Color(0xFF3157D5);
  static const Color pageBackground = Color(0xFFF5F7FB);

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      _goHome();
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openFeeExplorer() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const FeeExplorerScreen()),
    );
  }

  void _openHistory() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ImportHistoryScreen()),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? brandBlue : const Color(0xFF65718A),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? brandBlue : const Color(0xFF26334D),
        ),
      ),
      selected: selected,
      selectedTileColor: const Color(0xFFEEF1FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      onTap: onTap,
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 22),
              decoration: const BoxDecoration(color: Color(0xFFF5F7FB)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/branding/app_icon.png',
                    width: 48,
                    height: 48,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_balance_rounded,
                      size: 42,
                      color: brandBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'FeeDesk',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF17233D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Offline Fee Management',
                    style: TextStyle(fontSize: 12, color: Color(0xFF788397)),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 20, 18, 8),
              child: Text(
                'MAIN MENU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8993A5),
                  letterSpacing: 1,
                ),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.home_rounded,
              title: 'Home',
              onTap: () {
                Navigator.pop(context);
                _goHome();
              },
            ),
            _buildDrawerItem(
              icon: Icons.upload_file_rounded,
              title: 'Upload File',
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildDrawerItem(
              icon: Icons.manage_search_rounded,
              title: 'Fee Explorer',
              onTap: () {
                Navigator.pop(context);
                _openFeeExplorer();
              },
            ),
            _buildDrawerItem(
              icon: Icons.history_rounded,
              title: 'Import History',
              onTap: () {
                Navigator.pop(context);
                _openHistory();
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 17, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Works completely offline',
                    style: TextStyle(fontSize: 12, color: Color(0xFF788397)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectExcelFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _importMessage = null;
      _preview = null;
      _fileName = null;
      _manualMappings.clear();
    });

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (file == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('The selected file is empty.');
      }

      final preview = _service.inspectWorkbook(bytes);

      if (!mounted) return;

      setState(() {
        _fileName = file.name;
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not read workbook: $e';
        _loading = false;
      });
    }
  }

  Map<String, int?> _getMappings(SheetPreview sheet) {
    if (_manualMappings.containsKey(sheet.sheetName)) {
      return _manualMappings[sheet.sheetName]!;
    }

    final detected = _mappingService.detect(sheet);

    return {
      for (final dimension in ColumnMappingService.dimensionAliases.keys)
        dimension: detected.dimensionColumns[dimension],
    };
  }

  ColumnMappingResult _getEffectiveMapping(SheetPreview sheet) {
    final detected = _mappingService.detect(sheet);
    final selectedMappings = _getMappings(sheet);

    final dimensions = <String, int>{};

    for (final entry in selectedMappings.entries) {
      if (entry.value != null) {
        dimensions[entry.key] = entry.value!;
      }
    }

    final missingDimensions = ColumnMappingService.dimensionAliases.keys
        .where((dimension) => !dimensions.containsKey(dimension))
        .toList();

    return ColumnMappingResult(
      dimensionColumns: dimensions,
      expenditureColumns: detected.expenditureColumns,
      sourceTotalColumn: detected.sourceTotalColumn,
      missingDimensions: missingDimensions,
    );
  }

  ValidationResult _getValidationResult(SheetPreview sheet) {
    final mapping = _getEffectiveMapping(sheet);

    return _validationService.validate(sheet: sheet, mapping: mapping);
  }

  Future<void> _confirmImport(SheetPreview sheet) async {
    if (_fileName == null || _importing) return;

    final mapping = _getEffectiveMapping(sheet);

    final validation = _validationService.validate(
      sheet: sheet,
      mapping: mapping,
    );

    if (!validation.canImport) {
      setState(() {
        _importMessage =
            'Import blocked. Fix ${validation.errorCount} validation errors first.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm complete import'),
          content: Text(
            'File: $_fileName\n'
            'Worksheet: ${sheet.sheetName}\n'
            'Records: ${sheet.totalRows}\n'
            'Warnings: ${validation.warningCount}\n\n'
            'This will create a new dataset version and make it active. '
            'The previous version will be retained in import history.\n\n'
            'Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirm Import'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _importing = true;
      _importMessage = null;
    });

    try {
      final summary = await _importService.importCompleteWorkbook(
        fileName: _fileName!,
        sheet: sheet,
        mapping: mapping,
      );

      if (!mounted) return;

      setState(() {
        _importMessage =
            'Successfully imported ${summary.importedRows} records '
            'as version ${summary.versionNumber}.';
        _importing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import successful! Version ${summary.versionNumber}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _importMessage = 'Import failed: $e';
        _importing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Widget _buildMappingSummary(SheetPreview sheet) {
    final result = _getEffectiveMapping(sheet);

    final usedColumns = <int, int>{};

    for (final index in result.dimensionColumns.values) {
      usedColumns[index] = (usedColumns[index] ?? 0) + 1;
    }

    final hasDuplicateMappings = usedColumns.values.any((count) => count > 1);

    final mappingValid = result.isValid && !hasDuplicateMappings;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Column detection and mapping',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Icon(
                mappingValid ? Icons.check_circle : Icons.warning_amber_rounded,
                color: mappingValid ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 5),
              Text(
                mappingValid ? 'Mapped' : 'Needs attention',
                style: TextStyle(
                  color: mappingValid ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Required dimensions',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...ColumnMappingService.dimensionAliases.keys.map((dimension) {
            final columnIndex = result.dimensionColumns[dimension];
            final isFound = columnIndex != null;

            final header = isFound ? sheet.headers[columnIndex] : 'Not mapped';

            final isDuplicate = isFound && (usedColumns[columnIndex] ?? 0) > 1;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    !isFound || isDuplicate
                        ? Icons.error_outline
                        : Icons.check_circle,
                    size: 17,
                    color: !isFound || isDuplicate
                        ? Colors.orange
                        : Colors.green,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      dimension,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      header,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        color: !isFound || isDuplicate
                            ? Colors.orange
                            : const Color(0xFF3157D5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 24),
          const Text(
            'Expenditure columns',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (result.expenditureColumns.isEmpty)
            const Text(
              'No expenditure columns detected.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: result.expenditureColumns.map((index) {
                return Chip(
                  avatar: const Icon(Icons.currency_rupee, size: 15),
                  label: Text(
                    sheet.headers[index],
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: const Color(0xFFE8F5E9),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calculate_outlined,
                size: 18,
                color: Color(0xFF788397),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Source Total Fee', style: TextStyle(fontSize: 12)),
              ),
              Text(
                result.sourceTotalColumn == null
                    ? 'Not detected'
                    : sheet.headers[result.sourceTotalColumn!],
                style: TextStyle(
                  fontSize: 12,
                  color: result.sourceTotalColumn == null
                      ? Colors.orange
                      : const Color(0xFF3157D5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Total Fee is used for validation, not as an additional '
            'expenditure. This prevents double counting.',
            style: TextStyle(fontSize: 11, color: Color(0xFF788397)),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetCard(SheetPreview sheet) {
    final initialMappings = _getMappings(sheet);
    final validationResult = _getValidationResult(sheet);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_rounded, color: Color(0xFF3157D5)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sheet.sheetName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${sheet.totalRows} rows',
                style: const TextStyle(color: Color(0xFF788397), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Header row: ${sheet.headerRowNumber}',
            style: const TextStyle(color: Color(0xFF788397), fontSize: 12),
          ),
          const SizedBox(height: 10),
          const Text(
            'Detected columns:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: sheet.headers.map((header) {
              return Chip(
                label: Text(
                  header.isEmpty ? '(Empty)' : header,
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: const Color(0xFFEEF1FF),
              );
            }).toList(),
          ),
          _buildMappingSummary(sheet),
          const SizedBox(height: 20),
          const Text(
            'Review column mappings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ColumnMappingEditor(
            headers: sheet.headers,
            initialMappings: initialMappings,
            onChanged: (mappings) {
              setState(() {
                _manualMappings[sheet.sheetName] = mappings;
                _importMessage = null;
              });
            },
          ),
          const Divider(height: 32),
          ValidationReportPanel(result: validationResult),
          const SizedBox(height: 20),
          const Text(
            'Sample records (first 5):',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (sheet.sampleRows.isEmpty)
            const Text('No data rows found.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: sheet.headers.map((header) {
                  return DataColumn(
                    label: Text(header.isEmpty ? '(Empty)' : header),
                  );
                }).toList(),
                rows: sheet.sampleRows.map((row) {
                  return DataRow(
                    cells: row.map((value) {
                      return DataCell(
                        Text(value, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
          if (_importMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _importMessage!.startsWith('Successfully')
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _importMessage!,
                style: TextStyle(
                  color: _importMessage!.startsWith('Successfully')
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _importing || !validationResult.canImport
                  ? null
                  : () => _confirmImport(sheet),
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                _importing ? 'Importing...' : 'Import Complete Dataset',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandBlue,
          brightness: Brightness.light,
        ),
      ),
      child: Scaffold(
        backgroundColor: pageBackground,

        // Top bar with back button and menu.
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF17233D),
          elevation: 0,
          leading: IconButton(
            tooltip: 'Go back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _goBack,
          ),
          title: const Text(
            'FeeDesk',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
          ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Open navigation menu',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ],
        ),

        drawer: _buildNavigationDrawer(),

        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Excel Data',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF17233D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select, preview, map and validate your university fee workbook.',
                      style: TextStyle(color: Color(0xFF788397), fontSize: 13),
                    ),
                    const SizedBox(height: 25),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5EAF2)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.upload_file_rounded,
                            size: 48,
                            color: brandBlue,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Select your Excel workbook',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Supported format: .xlsx',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF788397),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _loading || _importing
                                ? null
                                : _selectExcelFile,
                            icon: const Icon(Icons.folder_open_rounded),
                            label: const Text('Browse Files'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 15,
                              ),
                            ),
                          ),
                          if (_loading) ...[
                            const SizedBox(height: 18),
                            const CircularProgressIndicator(),
                            const SizedBox(height: 8),
                            const Text('Reading workbook...'),
                          ],
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    if (_preview != null) ...[
                      const SizedBox(height: 25),
                      Text(
                        'Workbook: $_fileName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (_preview!.sheets.isEmpty)
                        const Text(
                          'No readable worksheets were found.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ..._preview!.sheets.map(_buildSheetCard),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
