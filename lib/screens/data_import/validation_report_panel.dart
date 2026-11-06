import 'package:flutter/material.dart';

import '../../services/excel_validation_service.dart';

class ValidationReportPanel extends StatelessWidget {
  final ValidationResult result;

  const ValidationReportPanel({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final canImport = result.canImport;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Validation Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${result.totalRows} rows inspected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  'Errors',
                  result.errorCount,
                  Colors.red,
                  Icons.error_outline,
                ),
                _summaryCard(
                  'Warnings',
                  result.warningCount,
                  Colors.orange,
                  Icons.warning_amber_rounded,
                ),
                _summaryCard(
                  'Rows',
                  result.totalRows,
                  Colors.blue,
                  Icons.table_rows_outlined,
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: canImport
                    ? Colors.green.withValues(alpha: 0.10)
                    : Colors.red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    canImport ? Icons.check_circle : Icons.block,
                    color: canImport ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      canImport
                          ? 'No blocking errors. Workbook is ready for import.'
                          : 'Import blocked. Fix the errors before continuing.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: canImport ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Issues found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (result.issues.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No issues found.'),
              )
            else
              ...result.issues.map(_buildIssue),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, int count, Color color, IconData icon) {
    return Container(
      width: 125,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildIssue(ValidationIssue issue) {
    final isError = issue.severity == ValidationSeverity.error;
    final color = isError ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.warning_amber,
            color: color,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Excel row ${issue.rowNumber} · ${issue.column}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(issue.message),
              ],
            ),
          ),
          Text(
            isError ? 'ERROR' : 'WARNING',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
