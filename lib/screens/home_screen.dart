import 'package:flutter/material.dart';

import '../models/media_category.dart';
import '../screens/converter_page.dart';
import '../widgets/glass_nav_bar.dart';
import '../widgets/matrix_rain_background.dart';

/// Home screen: horizontal layout with vertical glass navbar + tab content.
///
/// ARCHITECTURE:
///   - Stack: Matrix Rain (full window) → Content Row
///   - Row: GlassNavBar (left, 72px) + Expanded ConverterPage (right)
///   - _FadeIndexedStack preserves tab state with smooth fade+slide transitions
///
/// PERFORMANCE:
///   - Matrix Rain background is in its own RepaintBoundary (built-in)
///   - Navbar has its own RepaintBoundary (built-in)
///   - Content area wrapped in RepaintBoundary
///   - IndexedStack keeps all tabs alive, preventing re-initialization
import '../widgets/custom_title_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MediaCategory _activeTab = MediaCategory.photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── LAYER 1: Matrix Rain (full window) ───────────────────
          const Positioned.fill(child: MatrixRainBackground()),

          // ── LAYER 2: Navbar + Content ────────────────────────────
          Positioned.fill(
            child: Column(
              children: [
                // Custom draggable window title bar
                const CustomTitleBar(),

                
                // Rest of the app
                Expanded(
                  child: Row(
                    children: [
                      // Navbar
                      GlassNavBar(
                        selected: _activeTab,
                        onChanged: (tab) {
                          if (tab != _activeTab) {
                            setState(() => _activeTab = tab);
                          }
                        },
                      ),

                      // Content area
                      Expanded(
                        child: RepaintBoundary(
                          child: _FadeIndexedStack(
                            index: _activeTab.index,
                            children: MediaCategory.values.map((category) {
                              return ConverterPage(
                                key: ValueKey(category),
                                category: category,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom IndexedStack that fades between its children to preserve state
/// without losing the premium animated feel.
class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _FadeIndexedStack({
    required this.index,
    required this.children,
  });

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.02, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(_FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      _controller.reverse().then((_) {
        if (!mounted) return;
        setState(() => _currentIndex = widget.index);
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: IndexedStack(
          index: _currentIndex,
          children: widget.children,
        ),
      ),
    );
  }
}
