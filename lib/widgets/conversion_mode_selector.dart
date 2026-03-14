import 'package:flutter/material.dart';

import 'glass_container.dart';

/// Two-option selector: "Format Change" vs "Filetype Change".
/// Uses glass-styled toggle buttons — lightweight, no heavy animations.

enum ConversionMode { formatChange, filetypeChange }

class ConversionModeSelector extends StatelessWidget {
  final ConversionMode selected;
  final ValueChanged<ConversionMode> onChanged;

  const ConversionModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(8),
      borderRadius: 24, // Matches children nested radii constraint
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              icon: Icons.swap_horiz,
              label: 'Format Change',
              isActive: selected == ConversionMode.formatChange,
              onTap: () => onChanged(ConversionMode.formatChange),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeButton(
              icon: Icons.transform,
              label: 'Filetype Change',
              isActive: selected == ConversionMode.filetypeChange,
              onTap: () => onChanged(ConversionMode.filetypeChange),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        height: 56, // Touch friendly bounds (ui/ux rule)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // Nested radii (24 - 8)
          color: isActive
              ? Colors.white.withValues(alpha: 0.15) // Slightly brighter active state
              : Colors.transparent,
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
