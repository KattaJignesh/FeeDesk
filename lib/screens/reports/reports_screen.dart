import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/reports/report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();

  static const List<String> _dimensions = [
    'Admitted Batch',
    'Academic Year',
    'School',
    'Degree',
    'Program',
    'Study Year',
    'CQ/MQ',
  ];

  final Map<String, String?> _filters = {
    for (final dimension in _dimensions) dimension: null,
  };

  final Map<String, List<String>> _options = {};

  bool _loading = false;
  bool _filterLoading = true;
  String? _error;
  String? _message;
  int _matchingRecords = 0;
  int _matchingTotalPaise = 0;

  double _rupees(int? paise) {
    return (paise ?? 0) / 100.0;
  }

  String _money(int? paise) {
    return 'INR ${_rupees(paise).toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();
    _refreshFilters();
  }

  Future<void> _refreshFilters() async {
    if (mounted) {
      setState(() {
        _filterLoading = true;
        _error = null;
      });
    }

    try {
      final newOptions = <String, List<String>>{};

      for (final dimension in _dimensions) {
        final values = await _reportService.getFilterOptions(
          dimension,
          _filters,
        );

        newOptions[dimension] = values;

        final selected = _filters[dimension];

        if (selected != null && !values.contains(selected)) {
          _filters[dimension] = null;
        }
      }

      final data = await _reportService.getReportData(filters: _filters);

      if (!mounted) return;

      setState(() {
        _options
          ..clear()
          ..addAll(newOptions);

        _matchingRecords = data['record_count'] as int;
        _matchingTotalPaise = data['source_total_paise'] as int;

        _filterLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _filterLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _onFilterChanged(String dimension, String? value) async {
    final index = _dimensions.indexOf(dimension);

    setState(() {
      _filters[dimension] = value == 'All' ? null : value;

      // Changing a parent filter resets all dependent filters.
      for (int i = index + 1; i < _dimensions.length; i++) {
        _filters[_dimensions[i]] = null;
      }

      _message = null;
      _error = null;
    });

    await _refreshFilters();
  }

  Future<void> _resetFilters() async {
    setState(() {
      for (final dimension in _dimensions) {
        _filters[dimension] = null;
      }

      _message = null;
      _error = null;
    });

    await _refreshFilters();
  }

  List<String> _headers(List<String> categories) {
    return [
      'Admitted Batch',
      'Academic Year',
      'School',
      'Degree',
      'Program',
      'Study Year',
      'CQ/MQ',
      ...categories,
      'Calculated Total',
      'Source Total Fee',
      'Source Sheet',
      'Source Row',
    ];
  }

  List<dynamic> _recordValues(
    Map<String, dynamic> record,
    List<String> categories,
  ) {
    final amounts = record['category_amounts'] as Map<String, int>;

    return [
      record['admitted_batch'] ?? '',
      record['academic_year'] ?? '',
      record['school'] ?? '',
      record['degree'] ?? '',
      record['program'] ?? '',
      record['study_year'] ?? '',
      record['quota'] ?? '',
      ...categories.map((category) => _rupees(amounts[category])),
      _rupees((record['calculated_total_paise'] as num?)?.toInt()),
      _rupees((record['source_total_paise'] as num?)?.toInt()),
      record['source_sheet'] ?? '',
      record['source_row'] ?? '',
    ];
  }

  Future<void> _export(String format) async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final data = await _reportService.getReportData(filters: _filters);

      final records = data['records'] as List<Map<String, dynamic>>;

      if (records.isEmpty) {
        throw Exception('No fee records match the selected filters.');
      }

      final now = DateTime.now();

      final dateText =
          '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      late Uint8List bytes;
      late String fileName;

      switch (format) {
        case 'PDF':
          bytes = await _createPdf(data);
          fileName = 'MBU_Fee_Report_$dateText.pdf';
          break;

        case 'Excel':
          bytes = _createExcel(data);
          fileName = 'MBU_Fee_Report_$dateText.xlsx';
          break;

        default:
          bytes = _createCsv(data);
          fileName = 'MBU_Fee_Report_$dateText.csv';
      }

      final savedFile = await FilePicker.saveFile(
        dialogTitle: 'Save $format report',
        fileName: fileName,
        bytes: bytes,
      );

      if (!mounted) return;

      setState(() {
        _message = savedFile == null
            ? 'Export cancelled.'
            : '$format report saved successfully.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // CSV export.
  Uint8List _createCsv(Map<String, dynamic> data) {
    final categories = data['categories'] as List<String>;

    final records = data['records'] as List<Map<String, dynamic>>;

    final rows = <List<dynamic>>[
      ['MBU FEE MANAGER - FEE REPORT'],
      ['Generated on', DateTime.now().toString()],
      ['Total fee records', data['record_count']],
      ['Source total (INR)', _money(data['source_total_paise'] as int?)],
      [
        'Calculated total (INR)',
        _money(data['calculated_total_paise'] as int?),
      ],
      [],
      ['Applied filters'],
      ..._dimensions.map(
        (dimension) => [dimension, _filters[dimension] ?? 'All'],
      ),
      [],
      _headers(categories),
      ...records.map((record) => _recordValues(record, categories)),
    ];

    String escape(dynamic value) {
      final text = value is double
          ? value.toStringAsFixed(2)
          : value?.toString() ?? '';

      return '"${text.replaceAll('"', '""')}"';
    }

    final csv = rows.map((row) => row.map(escape).join(',')).join('\r\n');

    return Uint8List.fromList(utf8.encode('\uFEFF$csv'));
  }

  // Excel export.
  Uint8List _createExcel(Map<String, dynamic> data) {
    final excel = Excel.createExcel();
    final sheet = excel['Fee Records'];

    final categories = data['categories'] as List<String>;

    final records = data['records'] as List<Map<String, dynamic>>;

    final headers = _headers(categories);

    sheet.appendRow([TextCellValue('MBU FEE MANAGER - FEE REPORT')]);

    sheet.appendRow([
      TextCellValue('Generated on'),
      TextCellValue(DateTime.now().toString()),
    ]);

    sheet.appendRow([
      TextCellValue('Total fee records'),
      IntCellValue(data['record_count'] as int),
    ]);

    sheet.appendRow([
      TextCellValue('Source total (INR)'),
      DoubleCellValue(_rupees(data['source_total_paise'] as int?)),
    ]);

    sheet.appendRow([
      TextCellValue('Calculated total (INR)'),
      DoubleCellValue(_rupees(data['calculated_total_paise'] as int?)),
    ]);

    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('Applied filters')]);

    for (final dimension in _dimensions) {
      sheet.appendRow([
        TextCellValue(dimension),
        TextCellValue(_filters[dimension] ?? 'All'),
      ]);
    }

    sheet.appendRow([]);

    sheet.appendRow(headers.map((header) => TextCellValue(header)).toList());

    for (final record in records) {
      final values = _recordValues(record, categories);

      sheet.appendRow(
        values.map((value) {
          if (value is int) {
            return IntCellValue(value);
          }

          if (value is double) {
            return DoubleCellValue(value);
          }

          return TextCellValue(value.toString());
        }).toList(),
      );
    }

    for (int i = 0; i < headers.length; i++) {
      final width = i < 7
          ? 18.0
          : i < 7 + categories.length
          ? 22.0
          : i < 9 + categories.length
          ? 20.0
          : 15.0;

      sheet.setColumnWidth(i, width);
    }

    final result = excel.save();

    if (result == null) {
      throw Exception('Could not generate the Excel workbook.');
    }

    return Uint8List.fromList(result);
  }

  // PDF export.
  Future<Uint8List> _createPdf(Map<String, dynamic> data) async {
    final document = pw.Document();

    final categories = data['categories'] as List<String>;

    final records = data['records'] as List<Map<String, dynamic>>;

    final headers = _headers(categories);

    final tableRows = records.map((record) {
      final values = _recordValues(record, categories);

      return values.map((value) {
        if (value is double) {
          return value.toStringAsFixed(2);
        }

        return value.toString();
      }).toList();
    }).toList();

    final appliedFilters = _dimensions
        .map((dimension) => '$dimension: ${_filters[dimension] ?? 'All'}')
        .toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'MBU FEE MANAGER',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text('University Fee Structure Report'),
          pw.Text('Generated: ${DateTime.now()}'),
          pw.SizedBox(height: 12),
          pw.Text('Fee records: ${data['record_count']}'),
          pw.Text(
            'Source total: ${_money(data['source_total_paise'] as int?)}',
          ),
          pw.Text(
            'Calculated total: ${_money(data['calculated_total_paise'] as int?)}',
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Applied filters',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Wrap(
            spacing: 14,
            runSpacing: 5,
            children: appliedFilters
                .map(
                  (filter) =>
                      pw.Text(filter, style: const pw.TextStyle(fontSize: 8)),
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: tableRows,
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          ),
        ],
      ),
    );

    return Uint8List.fromList(await document.save());
  }

  Widget _filterDropdown(String dimension) {
    final values = _options[dimension] ?? [];

    final selected = _filters[dimension] ?? 'All';

    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: dimension,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
        ),
        items: [
          const DropdownMenuItem(value: 'All', child: Text('All')),
          ...values.map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(value, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: _filterLoading || _loading
            ? null
            : (value) => _onFilterChanged(dimension, value),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, color: Color(0xFF3157D5)),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Report Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _loading || _filterLoading ? null : _resetFilters,
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Reset filters'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_filterLoading)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: 13,
              runSpacing: 13,
              children: _dimensions.map(_filterDropdown).toList(),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.dataset_outlined, color: Color(0xFF16865B)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _filterLoading
                      ? 'Calculating matching records...'
                      : '$_matchingRecords matching fee records',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _money(_matchingTotalPaise),
                style: const TextStyle(
                  color: Color(0xFF16865B),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String format,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 17),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17233D),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF788397),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading || _filterLoading || _matchingRecords == 0
                  ? null
                  : () => _export(format),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text('Export $format'),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusMessage(String message, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(message, style: TextStyle(color: color, fontSize: 13)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports & Exports',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17233D),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Filter university fee records and export customised reports.',
            style: TextStyle(color: Color(0xFF788397), fontSize: 13),
          ),
          const SizedBox(height: 22),
          if (_message != null) _statusMessage(_message!, Colors.green),
          if (_error != null) _statusMessage(_error!, Colors.red),
          _buildFilters(),
          const SizedBox(height: 20),
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
          ],
          const Text(
            'Export filtered report',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17233D),
            ),
          ),
          const SizedBox(height: 13),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: 1.05,
              children: [
                _exportCard(
                  title: 'PDF Report',
                  description: 'Create a printable report with matching fee records and totals.',
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFD94A4A),
                  format: 'PDF',
                ),
                _exportCard(
                  title: 'Excel Workbook',
                  description: 'Export filtered records and expenditure categories into XLSX.',
                  icon: Icons.table_chart_rounded,
                  color: const Color(0xFF16865B),
                  format: 'Excel',
                ),
                _exportCard(
                  title: 'CSV Data',
                  description: 'Export filtered records as a CSV spreadsheet.',
                  icon: Icons.description_rounded,
                  color: const Color(0xFF3157D5),
                  format: 'CSV',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
