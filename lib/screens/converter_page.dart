import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/media_category.dart';
import '../services/converter_service.dart';
import '../services/format_registry.dart';
import '../widgets/conversion_mode_selector.dart';
import '../widgets/conversion_status.dart';
import '../widgets/file_selector.dart';
import '../widgets/format_dropdown.dart';
import '../widgets/glass_container.dart';

/// Content page for each media category tab.
///
/// FLOW:
///   1. Select file (filtered by category)
///   2. Choose mode: Format Change or Filetype Change
///   3. Format Change → same-type format dropdown
///      Filetype Change → target category dropdown → format dropdown
///   4. Convert + status
///
/// PERFORMANCE:
///   - Wrapped in RepaintBoundary by the parent (home_screen)
///   - Uses const where possible, minimal setState scope

class ConverterPage extends StatefulWidget {
  final MediaCategory category;

  const ConverterPage({super.key, required this.category});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  File? _selectedFile;
  ConversionMode _mode = ConversionMode.formatChange;

  // Format Change state
  String? _selectedFormat;
  List<String> _availableFormats = [];

  // Filetype Change state
  MediaCategory? _targetCategory;
  String? _crossFormat;
  List<String> _crossFormats = [];

  // Conversion state
  ConversionStatus _status = ConversionStatus.idle;
  String _statusMessage = '';
  Duration? _elapsed;
  String? _outputPath;
  final _outputPathController = TextEditingController();

  @override
  void didUpdateWidget(ConverterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _resetAll();
    }
  }

  @override
  void dispose() {
    _outputPathController.dispose();
    super.dispose();
  }

  void _resetAll() {
    setState(() {
      _selectedFile = null;
      _mode = ConversionMode.formatChange;
      _selectedFormat = null;
      _availableFormats = [];
      _targetCategory = null;
      _crossFormat = null;
      _crossFormats = [];
      _status = ConversionStatus.idle;
      _statusMessage = '';
      _elapsed = null;
      _outputPath = null;
      _outputPathController.clear();
    });
  }

  void _onFileSelected(File file) {
    setState(() {
      _selectedFile = file;
      _status = ConversionStatus.idle;
      _statusMessage = '';
      _elapsed = null;
      _outputPath = null;
      _outputPathController.clear();
      _updateFormats();
    });
  }

  void _onModeChanged(ConversionMode mode) {
    setState(() {
      _mode = mode;
      _selectedFormat = null;
      _targetCategory = null;
      _crossFormat = null;
      _crossFormats = [];
      _outputPathController.clear();
      _updateFormats();
    });
  }

  void _updateFormats() {
    if (_selectedFile == null) return;
    final ext = _selectedFile!.path.split('.').last;

    if (_mode == ConversionMode.formatChange) {
      _availableFormats = FormatRegistry.sameTypeFormats(
        widget.category,
        ext,
      );
    }
  }

  void _onFormatChanged(String? format) {
    setState(() {
      _selectedFormat = format;
    });
    _autoFillOutputPath(format);
  }

  void _onTargetCategoryChanged(MediaCategory? target) {
    if (target == null || _selectedFile == null) return;
    final ext = _selectedFile!.path.split('.').last;

    setState(() {
      _targetCategory = target;
      _crossFormat = null;
      _crossFormats = FormatRegistry.crossTypeFormats(target, ext);
      _outputPathController.clear();
    });
  }

  void _onCrossFormatChanged(String? format) {
    setState(() {
      _crossFormat = format;
    });
    _autoFillOutputPath(format);
  }

  void _autoFillOutputPath(String? format) {
    if (format != null && _selectedFile != null) {
      final inputPath = _selectedFile!.path;
      final baseName = inputPath.contains('.')
          ? inputPath.substring(0, inputPath.lastIndexOf('.'))
          : inputPath;
      _outputPathController.text = '$baseName.$format';
    }
  }

  Future<void> _onBrowseOutput() async {
    final format = _mode == ConversionMode.formatChange
        ? _selectedFormat
        : _crossFormat;
    if (_selectedFile == null || format == null) return;

    final inputName = _selectedFile!.path.split(Platform.pathSeparator).last;
    final baseName = inputName.contains('.')
        ? inputName.substring(0, inputName.lastIndexOf('.'))
        : inputName;
    final suggestedName = '$baseName.$format';

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
    final format = _mode == ConversionMode.formatChange
        ? _selectedFormat
        : _crossFormat;
    if (_selectedFile == null || format == null) return;
    final outputPath = _outputPathController.text.trim();
    if (outputPath.isEmpty) return;

    setState(() {
      _status = ConversionStatus.converting;
      _statusMessage = '';
      _elapsed = null;
      _outputPath = null;
    });

    final result = await ConverterService.convertInBackground(
      inputPath: _selectedFile!.path,
      outputFormat: format,
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

  bool get _canConvert {
    final format = _mode == ConversionMode.formatChange
        ? _selectedFormat
        : _crossFormat;
    return _selectedFile != null &&
        format != null &&
        _outputPathController.text.trim().isNotEmpty &&
        _status != ConversionStatus.converting;
  }

  @override
  Widget build(BuildContext context) {
    // Files tab — coming soon
    if (widget.category == MediaCategory.files) {
      return Center(
        child: GlassContainer(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'File conversion engine is under development.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final inputExts = FormatRegistry.inputFormatsForCategory(widget.category);

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. File Selector
                    FileSelector(
                      selectedFile: _selectedFile,
                      onFileSelected: _onFileSelected,
                      allowedExtensions: inputExts,
                    ),

                    // 2. Conversion Mode
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 16),
                      ConversionModeSelector(
                        selected: _mode,
                        onChanged: _onModeChanged,
                      ),
                    ],

                    // 3. Format Selection
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 16),
                      _buildFormatSection(),
                    ],

                    // 4. Output Path
                    if (_activeFormat != null) ...[
                      const SizedBox(height: 16),
                      _buildOutputPath(),
                    ],

                    // 5. Convert Button
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _canConvert ? _onConvert : null,
                        icon: const Icon(Icons.transform),
                        label: const Text(
                          'Convert',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 6. Status
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
    );
  }

  String? get _activeFormat =>
      _mode == ConversionMode.formatChange ? _selectedFormat : _crossFormat;

  Widget _buildFormatSection() {
    if (_mode == ConversionMode.formatChange) {
      return FormatDropdown(
        key: ValueKey('fmt_${_selectedFile?.path}'),
        formats: _availableFormats,
        selectedFormat: _selectedFormat,
        onFormatChanged: _onFormatChanged,
      );
    }

    // Filetype Change — two-step: pick target category, then format
    final targets = FormatRegistry.crossTypeTargets(widget.category);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.category,
                size: 20,
                color: Colors.white.withValues(alpha: 0.8),
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  borderRadius: 35,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MediaCategory>(
                      value: _targetCategory,
                      isExpanded: true,
                      alignment: AlignmentDirectional.center,
                      dropdownColor: const Color(0xE01A1A2E),
                      borderRadius: BorderRadius.circular(25),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      hint: Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Select type',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      items: targets.map((cat) {
                        final label = cat.name[0].toUpperCase() +
                            cat.name.substring(1);
                        return DropdownMenuItem(
                          value: cat,
                          alignment: AlignmentDirectional.center,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: _onTargetCategoryChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Second dropdown: format within target category
          if (_targetCategory != null && _crossFormats.isNotEmpty) ...[
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              borderRadius: 35,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _crossFormat,
                  isExpanded: true,
                  alignment: AlignmentDirectional.center,
                  dropdownColor: const Color(0xE01A1A2E),
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
                  items: _crossFormats.map((f) {
                    return DropdownMenuItem(
                      value: f,
                      alignment: AlignmentDirectional.center,
                      child: Text(
                        '.${f.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                  onChanged: _onCrossFormatChanged,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutputPath() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 25.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Save to:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.6),
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
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Output file path...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _onBrowseOutput,
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: 'Browse...',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
