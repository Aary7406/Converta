import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/converter_service.dart';
import '../services/format_registry.dart';
import '../widgets/conversion_status.dart';
import '../widgets/file_selector.dart';
import '../widgets/format_dropdown.dart';
import '../widgets/matrix_rain_background.dart';
import '../widgets/glass_container.dart';

/// Home screen with glassmorphic UI.
///
/// THE KEY TO GLASSMORPHISM:
///   This screen wraps everything in a Stack:
///     Layer 1 (bottom): A gradient background with abstract shapes
///     Layer 2 (top):    The scrollable content with GlassContainer cards
///
///   When BackdropFilter (inside GlassContainer) blurs "behind" a card,
///   it blurs Layer 1 — the gradient. This creates the frosted glass look.
///   It's EXACTLY like CSS backdrop-filter: blur() on a gradient background.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedFile;
  List<String> _availableFormats = [];
  String? _selectedFormat;
  ConversionStatus _status = ConversionStatus.idle;
  String _statusMessage = '';
  Duration? _elapsed;
  String? _outputPath;
  final _outputPathController = TextEditingController();

  @override
  void dispose() {
    _outputPathController.dispose();
    super.dispose();
  }

  void _onFileSelected(File file) {
    final ext = file.path.split('.').last;
    final formats = FormatRegistry.getOutputFormats(ext);

    setState(() {
      _selectedFile = file;
      _availableFormats = formats;
      _selectedFormat = null;
      _status = ConversionStatus.idle;
      _statusMessage = '';
      _elapsed = null;
      _outputPath = null;
      _outputPathController.clear();
    });
  }

  void _onFormatChanged(String? format) {
    setState(() {
      _selectedFormat = format;
    });

    if (format != null && _selectedFile != null) {
      final inputPath = _selectedFile!.path;
      final baseName = inputPath.contains('.')
          ? inputPath.substring(0, inputPath.lastIndexOf('.'))
          : inputPath;
      _outputPathController.text = '$baseName.$format';
    }
  }

  Future<void> _onBrowseOutput() async {
    if (_selectedFile == null || _selectedFormat == null) return;

    final inputName = _selectedFile!.path.split(Platform.pathSeparator).last;
    final baseName = inputName.contains('.')
        ? inputName.substring(0, inputName.lastIndexOf('.'))
        : inputName;
    final suggestedName = '$baseName.$_selectedFormat';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save converted file as',
      fileName: suggestedName,
      type: FileType.any,
    );

    if (result != null) {
      _outputPathController.text = result;
    }
  }

  Future<void> _onConvert() async {
    if (_selectedFile == null || _selectedFormat == null) return;
    final outputPath = _outputPathController.text.trim();
    if (outputPath.isEmpty) return;

    setState(() {
      _status = ConversionStatus.converting;
      _statusMessage = '';
      _elapsed = null;
      _outputPath = null;
    });

    final result = await ConverterService.convert(
      inputPath: _selectedFile!.path,
      outputFormat: _selectedFormat!,
      outputPath: outputPath,
    );

    if (!mounted) return;

    setState(() {
      _status = result.success
          ? ConversionStatus.success
          : ConversionStatus.error;
      _statusMessage = result.message;
      _elapsed = result.elapsed;
      _outputPath = result.success ? result.outputPath : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canConvert =
        _selectedFile != null &&
        _selectedFormat != null &&
        _outputPathController.text.trim().isNotEmpty &&
        _status != ConversionStatus.converting;

    return Scaffold(
      // ── Stack: gradient background + content on top ──────────────
      // This is the secret to making BackdropFilter work.
      // Without this gradient, there's nothing for the blur to blur!
      body: Stack(
        children: [
          // ── LAYER 1: Matrix Rain Background ────────────────────────
          // Digital rain columns on AMOLED black.
          // BackdropFilter (inside GlassContainer) blurs/refracts this layer.
          const Positioned.fill(child: MatrixRainBackground()),

          // ── LAYER 2: Scrollable Content ─────────────────────────────
          // The glass cards sit here. Their BackdropFilter blurs Layer 1.
          Positioned.fill(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min, // Allows vertical centering
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. File Selector
                            FileSelector(
                              selectedFile: _selectedFile,
                              onFileSelected: _onFileSelected,
                            ),
                            const SizedBox(height: 16),

                            // 2. Format Dropdown
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _selectedFile != null
                                  ? FormatDropdown(
                                      key: ValueKey(_selectedFile!.path),
                                      formats: _availableFormats,
                                      selectedFormat: _selectedFormat,
                                      onFormatChanged: _onFormatChanged,
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            // 3. Output Path
                            if (_selectedFormat != null) ...[
                              const SizedBox(height: 16),
                              GlassContainer(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Save to:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _outputPathController,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'Consolas',
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Output file path...',
                                              hintStyle: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.15),
                                                ),
                                              ),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: _onBrowseOutput,
                                          icon: const Icon(
                                            Icons.folder_open,
                                            size: 20,
                                          ),
                                          tooltip: 'Browse...',
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // 4. Convert Button
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: canConvert ? _onConvert : null,
                                icon: const Icon(Icons.transform),
                                label: const Text(
                                  'Convert',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 5. Status
                            ConversionStatusWidget(
                              status: _status,
                              message: _statusMessage,
                              elapsed: _elapsed,
                              outputPath: _outputPath,
                            ),
                          ],
                        ),
                      ),
                    ),
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
