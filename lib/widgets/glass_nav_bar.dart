import 'package:flutter/material.dart';

import '../models/media_category.dart';
import 'glass_container.dart';

/// Vertical liquid glass navbar with animated tab indicator.
///
/// PERFORMANCE:
///   - Uses AnimatedAlign for the indicator (single animation, no rebuild)
///   - const constructors for static elements
///   - RepaintBoundary isolates the navbar from content repaints

const double _kItemHeight = 72.0; // 8 * 9
const double _kNavWidth = 72.0;   // 8 * 9

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

  // Catppuccin Macchiato/Mocha Palette for fluid tab transitions
  static const _catppuccinColors = [
    Color(0xFFC6A0F6), // Mauve (Photo)
    Color(0xFF8AADF4), // Blue (Video)
    Color(0xFFA6DA95), // Green (Audio)
    Color(0xFFF5A97F), // Peach (Files)
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _tabs.indexWhere((t) => t.$1 == selected);
    final activeColor = _catppuccinColors[selectedIndex % _catppuccinColors.length];
    
    final itemCount = _tabs.length;
    // Total height of the item column
    final totalHeight = itemCount * _kItemHeight;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16), // 8pt grid
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          borderRadius: 40, // More rounded
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
                      // ── Animated glowing vertical pill indicator ──
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        // Center the 28px tall pill vertically within the 60px item height
                        top: selectedIndex * _kItemHeight + (_kItemHeight - 28) / 2,
                        left: 10, // Inset from the left edge to float near the icon
                        width: 4, // Thin, elegant pill
                        height: 28, // Taller pill
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4), // Pill shape
                            color: activeColor, // Solid Catppuccin color
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.5), // Glowing effect
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
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

class _NavItem extends StatefulWidget {
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
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  // @flutter-expert: Encapsulating state locally drastically improves efficiency
  // State changes here only rebuild the specific icon, NOT the entire column/navbar.
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Micro-interactions scaling
    final isFocused = widget.isActive || _isHovered;
    final scale = isFocused ? 1.05 : 1.0; 
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _kNavWidth,
          height: _kItemHeight,
          child: Center(
            child: AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      widget.icon,
                      key: ValueKey(widget.icon),
                      size: 22,
                      // Lighter off-state so hover state difference is clearer
                      color: isFocused
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 8), // 8pt grid
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
                      color: isFocused
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
