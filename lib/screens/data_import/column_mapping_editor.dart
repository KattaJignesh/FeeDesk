import 'package:flutter/material.dart';

import '../../services/column_mapping_service.dart';

class ColumnMappingEditor extends StatefulWidget {
  final List<String> headers;
  final Map<String, int?> initialMappings;
  final ValueChanged<Map<String, int?>> onChanged;

  const ColumnMappingEditor({
    super.key,
    required this.headers,
    required this.initialMappings,
    required this.onChanged,
  });

  @override
  State<ColumnMappingEditor> createState() => _ColumnMappingEditorState();
}

class _ColumnMappingEditorState extends State<ColumnMappingEditor> {
  late Map<String, int?> _mappings;

  @override
  void initState() {
    super.initState();
    _initializeMappings();
  }

  @override
  void didUpdateWidget(covariant ColumnMappingEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.headers != widget.headers ||
        oldWidget.initialMappings != widget.initialMappings) {
      _initializeMappings();
    }
  }

  void _initializeMappings() {
    _mappings = {
      for (final dimension in ColumnMappingService.dimensionAliases.keys)
        dimension: widget.initialMappings[dimension],
    };
  }

  void _updateMapping(String dimension, int? columnIndex) {
    setState(() {
      _mappings[dimension] = columnIndex;
    });

    widget.onChanged(Map<String, int?>.from(_mappings));
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = ColumnMappingService.dimensionAliases.keys;

    final mappedCount = _mappings.values.where((value) => value != null).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review column mapping',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17233D),
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Match each required field with its corresponding Excel column.',
            style: TextStyle(fontSize: 12, color: Color(0xFF788397)),
          ),

          const SizedBox(height: 16),

          Text(
            '$mappedCount of ${dimensions.length} dimensions mapped',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF3157D5),
            ),
          ),

          const SizedBox(height: 14),

          ...dimensions.map((dimension) {
            final selectedIndex = _mappings[dimension];

            final validSelection =
                selectedIndex != null &&
                selectedIndex >= 0 &&
                selectedIndex < widget.headers.length;

            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dimension,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 7),

                  DropdownButtonFormField<int?>(
                    initialValue: validSelection ? selectedIndex : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Select Excel column',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Not mapped'),
                      ),
                      ...List.generate(widget.headers.length, (index) {
                        final header = widget.headers[index].trim();

                        return DropdownMenuItem<int?>(
                          value: index,
                          child: Text(
                            header.isEmpty
                                ? 'Column ${index + 1} (Empty header)'
                                : header,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      _updateMapping(dimension, value);
                    },
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 5),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5FC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Automatic detection provides the initial selections. '
              'You can change any selection manually.',
              style: TextStyle(fontSize: 11, color: Color(0xFF53627A)),
            ),
          ),
        ],
      ),
    );
  }
}
