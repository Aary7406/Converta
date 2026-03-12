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
///   - AnimatedSwitcher handles tab transitions with slide + fade
///
/// PERFORMANCE:
///   - Matrix Rain background is in its own RepaintBoundary (built-in)
///   - Navbar has its own RepaintBoundary (built-in)
///   - Content area wrapped in RepaintBoundary
///   - AnimatedSwitcher only rebuilds the content widget, not the navbar
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
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.05, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: ConverterPage(
                              key: ValueKey(_activeTab),
                              category: _activeTab,
                            ),
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
