import 'package:flutter/material.dart';

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
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedFormat,
                  isExpanded: true,
                  alignment: AlignmentDirectional.center,
                  dropdownColor: const Color(0xE01A1A2E), // Translucent dark
                  borderRadius: BorderRadius.circular(25),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  hint: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Select format',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  items: formats.map((format) {
                    return DropdownMenuItem<String>(
                      value: format,
                      alignment: AlignmentDirectional.center,
                      child: Text(
                        '.${format.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                  onChanged: onFormatChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
