import 'dart:io';

import 'package:flutter/material.dart';

import 'glass_container.dart';

/// Glassmorphic status display.

enum ConversionStatus { idle, converting, success, error }

class ConversionStatusWidget extends StatelessWidget {
  final ConversionStatus status;
  final String message;
  final Duration? elapsed;
  final String? outputPath;

  const ConversionStatusWidget({
    super.key,
    required this.status,
    this.message = '',
    this.elapsed,
    this.outputPath,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                    if (status == ConversionStatus.success && elapsed != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Completed in ${_formatDuration(elapsed!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (status == ConversionStatus.success && outputPath != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved to:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    outputPath!,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Consolas',
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openFile(outputPath!),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open File'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openFolder(outputPath!),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Open Folder'),
                  ),
                ),
              ],
            ),
          ],

          if (message.isNotEmpty && status == ConversionStatus.error)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Consolas',
                    color: Colors.redAccent,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFile(String path) {
    Process.run('cmd', ['/c', 'start', '', path]);
  }

  void _openFolder(String path) {
    Process.run('explorer', ['/select,', path]);
  }

  Widget _buildIcon() {
    switch (status) {
      case ConversionStatus.idle:
        return Icon(
          Icons.hourglass_empty,
          size: 28,
          color: Colors.white.withValues(alpha: 0.4),
        );
      case ConversionStatus.converting:
        return const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        );
      case ConversionStatus.success:
        return const Icon(
          Icons.check_circle,
          size: 28,
          color: Colors.greenAccent,
        );
      case ConversionStatus.error:
        return const Icon(Icons.error, size: 28, color: Colors.redAccent);
    }
  }

  String get _statusText {
    switch (status) {
      case ConversionStatus.idle:
        return 'Ready to convert';
      case ConversionStatus.converting:
        return 'Converting...';
      case ConversionStatus.success:
        return 'Conversion successful!';
      case ConversionStatus.error:
        return 'Conversion failed';
    }
  }

  Color get _statusColor {
    switch (status) {
      case ConversionStatus.idle:
        return Colors.white.withValues(alpha: 0.5);
      case ConversionStatus.converting:
        return Colors.purpleAccent;
      case ConversionStatus.success:
        return Colors.greenAccent;
      case ConversionStatus.error:
        return Colors.redAccent;
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
}
