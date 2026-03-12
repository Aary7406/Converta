import 'package:flutter/material.dart';

import '../models/media_category.dart';
import 'glass_container.dart';

/// Vertical liquid glass navbar with animated tab indicator.
///
/// PERFORMANCE:
///   - Uses AnimatedAlign for the indicator (single animation, no rebuild)
///   - const constructors for static elements
///   - RepaintBoundary isolates the navbar from content repaints

const double _kItemHeight = 64.0;
const double _kNavWidth = 64.0;
const double _kIndicatorInset = 6.0;

class GlassNavBar extends StatelessWidget {
  final MediaCategory selected;
  final ValueChanged<MediaCategory> onChanged;

  const GlassNavBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _tabs = [
    (MediaCategory.photo, Icons.photo_outlined, Icons.photo, 'Photo'),
    (MediaCategory.video, Icons.videocam_outlined, Icons.videocam, 'Video'),
    (MediaCategory.audio, Icons.audiotrack_outlined, Icons.audiotrack, 'Audio'),
    (MediaCategory.files, Icons.folder_outlined, Icons.folder, 'Files'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _tabs.indexWhere((t) => t.$1 == selected);
    final itemCount = _tabs.length;
    // Total height of the item column
    final totalHeight = itemCount * _kItemHeight;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 12, bottom: 12),
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          borderRadius: 50,
          child: SizedBox(
            width: _kNavWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stack: indicator behind items, both share same layout
                SizedBox(
                  height: totalHeight,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // ── Animated indicator pill ───────────────────
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        top: selectedIndex * _kItemHeight + _kIndicatorInset,
                        left: _kIndicatorInset,
                        right: _kIndicatorInset,
                        height: _kItemHeight - _kIndicatorInset * 2,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),

                      // ── Tab items (centered column) ──────────────
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _tabs.map((tab) {
                          final isActive = tab.$1 == selected;
                          return _NavItem(
                            icon: isActive ? tab.$3 : tab.$2,
                            label: tab.$4,
                            isActive: isActive,
                            onTap: () {
                              if (!isActive) onChanged(tab.$1);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _kNavWidth,
        height: _kItemHeight,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: 22,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
