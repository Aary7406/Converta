import 'package:flutter/material.dart';

import 'custom_glass_dropdown.dart';
import 'glass_container.dart';

/// Glassmorphic dropdown for selecting the output format.

class FormatDropdown extends StatelessWidget {
  final List<String> formats;
  final String? selectedFormat;
  final ValueChanged<String?> onFormatChanged;

  const FormatDropdown({
    super.key,
    required this.formats,
    required this.selectedFormat,
    required this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          const Text(
            'Convert to:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              borderRadius: 35,
              child: CustomGlassDropdown<String>(
                value: selectedFormat,
                hint: const Text('Select format'),
                items: formats.map((format) {
                  return DropdownMenuItem<String>(
                    value: format,
                    child: Text('.${format.toUpperCase()}'),
                  );
                }).toList(),
                onChanged: onFormatChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
