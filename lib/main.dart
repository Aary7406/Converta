import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/home_screen.dart';

/// APP ENTRY POINT — Windows 10 focused.
///
/// GLASSMORPHISM APPROACH (simulated, like CSS):
///   On Windows 10, we can't blur the actual desktop behind our window
///   without using a buggy Microsoft API. So instead, we do what web devs do:
///
///   1. Create a beautiful gradient BACKGROUND inside our app
///   2. Place frosted glass cards ON TOP using BackdropFilter
///   3. BackdropFilter blurs the gradient behind each card
///   4. Result: looks like frosted glass — same as CSS backdrop-filter: blur()
///
///   The window itself is opaque (solid) — no OS transparency needed.
///   This approach is lag-free, works on ALL Windows versions, and looks great.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Window setup ──────────────────────────────────────────────────
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(700, 750),
    minimumSize: Size(500, 600),
    center: true,
    title: 'Converta',
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ConverterApp());
}

class ConverterApp extends StatelessWidget {
  const ConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Converta',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,

        // Scaffold background is transparent so the gradient
        // from HomeScreen shows through.
        scaffoldBackgroundColor: Colors.transparent,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
      ),

      home: const HomeScreen(),
    );
  }
}
