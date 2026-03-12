import 'package:flutter/cupertino.dart';
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
                
                // Mac-like (rounded circles) colored window controls
                // Positioned on the right for native Windows/Steam feel
                _WindowControlButton(
                  icon: CupertinoIcons.minus,
                  color: const Color(0xFFFFBD2E), // Mac Yellow
                  onTap: () => windowManager.minimize(),
                ),
                const SizedBox(width: 8),
                _WindowControlButton(
                  icon: CupertinoIcons.plus, // maximize
                  color: const Color(0xFF28C940), // Mac Green
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
                    }
                  },
                ),
                const SizedBox(width: 8),
                _WindowControlButton(
                  icon: CupertinoIcons.xmark,
                  color: const Color(0xFFFF5F56), // Mac Red
                  onTap: () => windowManager.close(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WindowControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isHovered ? 1.0 : 0.0, // Only show inner icon on hover like macOS
              child: Icon(
                widget.icon,
                size: 10,
                color: Colors.black.withValues(alpha: 0.6), 
              ),
            ),
          ),
        ),
      ),
    );
  }
}
