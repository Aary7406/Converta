import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// A sleek, frameless title bar with Mac-like monochrome circular icons 
/// placed on the right (Windows/Steam style).
class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          // Drag area covers the entire title bar
          const DragToMoveArea(
            child: SizedBox.expand(),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Title
                const Text(
                  'Converta',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                
                const Spacer(),
                
                // Windows 7 Style Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WindowsTitleBarButton(
                      icon: Icons.minimize,
                      onTap: () => windowManager.minimize(),
                    ),
                    _WindowsTitleBarButton(
                      // We use crop_square for maximize and fullscreen_exit for restore
                      icon: Icons.crop_square, 
                      onTap: () async {
                        if (await windowManager.isMaximized()) {
                          windowManager.unmaximize();
                        } else {
                          windowManager.maximize();
                        }
                      },
                    ),
                    _WindowsTitleBarButton(
                      icon: Icons.close,
                      isClose: true,
                      onTap: () => windowManager.close(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowsTitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowsTitleBarButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WindowsTitleBarButton> createState() => _WindowsTitleBarButtonState();
}

class _WindowsTitleBarButtonState extends State<_WindowsTitleBarButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Windows 7 Classic Close Hover Red: #E81123
    final hoverColor = widget.isClose 
        ? const Color(0xFFE81123) 
        : Colors.white.withValues(alpha: 0.1);
        
    final iconColor = (isHovered && widget.isClose)
        ? Colors.white
        : Colors.white70;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 46, // Standard Windows title bar button width
          height: 40, // Match title bar height
          decoration: BoxDecoration(
            color: isHovered ? hoverColor : Colors.transparent,
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
