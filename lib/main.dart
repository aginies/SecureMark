import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'l10n/app_localizations.dart';
import 'watermark_processor.dart';

class _ProcessedFile {
  const _ProcessedFile({
    required this.sourcePath,
    required this.result,
  });

  final String sourcePath;
  final ProcessResult result;
}

void main() {
  runApp(const WatermarkApp());
}

class WatermarkApp extends StatelessWidget {
  const WatermarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const WatermarkPage(),
    );
  }
}

class WatermarkPage extends StatefulWidget {
  const WatermarkPage({super.key});

  @override
  State<WatermarkPage> createState() => _WatermarkPageState();
}

class _WatermarkPageState extends State<WatermarkPage> {
  final TextEditingController _textController = TextEditingController();
  final TransformationController _transformationController = TransformationController();
  double _transparency = 90;
  double _density = 35;
  double _fontSize = 24;
  int _jpegQuality = 75;
  int? _targetSize = 1280;
  bool _includeTimestamp = true;
  bool _useRandomColor = true;
  Color _selectedColor = Colors.red;
  bool _dragging = false;
  bool _processing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String _progressMessage = '';
  List<String> _selectedPaths = <String>[];
  List<_ProcessedFile> _processedFiles = <_ProcessedFile>[];
  int _previewIndex = 0;
  CancellationToken? _cancellationToken;

  bool get _supportsDesktopDrop =>
      !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  _ProcessedFile? get _currentProcessedFile {
    if (_processedFiles.isEmpty) {
      return null;
    }
    final safeIndex = _previewIndex.clamp(0, _processedFiles.length - 1);
    return _processedFiles[safeIndex];
  }

  @override
  void dispose() {
    _textController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            onPressed: _showExpertOptions,
            tooltip: l10n.expertOptions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
                final controls = _buildControlsPanel(theme);
                final preview = _buildPreviewPanel(theme);

                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 360,
                          child: SingleChildScrollView(child: controls),
                        ),
                        const SizedBox(width: 20),
                        Expanded(child: preview),
                      ],
                    ),
                  );
                }

                // Mobile layout with larger preview area
                final screenHeight = constraints.maxHeight;
                
                // Use more conservative sizing for better compatibility
                final previewHeight = isMobile 
                    ? (screenHeight * 0.5).clamp(350.0, 500.0) // 50% of screen height, min 350px, max 500px
                    : 420.0; // Default height for web/desktop narrow screens

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      controls,
                      const SizedBox(height: 16),
                      SizedBox(height: previewHeight, child: preview),
                      const SizedBox(height: 16),
                      _buildAuthorFooter(theme),
                    ],
                  ),
                );
              },
            ),
            if (_processing) _buildLoadingOverlay(theme),
          ],
        ),
      ),
    );
  }
  Widget _buildControlsPanel(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextCard(),
        const SizedBox(height: 16),
        _buildPrimaryActionCard(),
        const SizedBox(height: 16),
        _buildColorCard(),
        const SizedBox(height: 16),
        _buildActionButtons(),
        const SizedBox(height: 16),
        Text(
          _statusMessage,
          style: theme.textTheme.bodyMedium,
        ),
        if (_processedFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.readyToSaveFiles(_processedFiles.length),
            style: theme.textTheme.bodySmall,
          ),
          // Only show save location info on desktop platforms where Save button is visible
          if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined, 
                    size: 16, 
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getSaveLocationInfo(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (_supportsDesktopDrop) ...[
          const SizedBox(height: 16),
          _buildDropArea(theme),
        ],
      ],
    );
  }

  void _showExpertOptions() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.settings_suggest_outlined),
                  const SizedBox(width: 12),
                  Text(l10n.expertOptions),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.fontSizeValue(_fontSize.round()), style: theme.textTheme.titleSmall),
                  Slider(
                    value: _fontSize,
                    min: 8,
                    max: 48,
                    divisions: 10,
                    onChanged: (value) {
                      setDialogState(() {
                        _fontSize = value;
                      });
                      setState(() {
                        _fontSize = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.jpegQualityValue(_jpegQuality), style: theme.textTheme.titleSmall),
                  Slider(
                    value: _jpegQuality.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 18,
                    onChanged: (value) {
                      setDialogState(() {
                        _jpegQuality = value.round();
                      });
                      setState(() {
                        _jpegQuality = value.round();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.imageResizingLabel(_targetSize?.toString() ?? l10n.resizeNone), 
                    style: theme.textTheme.titleSmall,
                  ),
                  DropdownButton<int?>(
                    value: _targetSize,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text(l10n.resizeNone)),
                      const DropdownMenuItem<int?>(value: 2048, child: Text('2048 px')),
                      const DropdownMenuItem<int?>(value: 1600, child: Text('1600 px')),
                      const DropdownMenuItem<int?>(value: 1280, child: Text('1280 px')),
                      const DropdownMenuItem<int?>(value: 1024, child: Text('1024 px')),
                      const DropdownMenuItem<int?>(value: 800, child: Text('800 px')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _targetSize = value;
                      });
                      setState(() {
                        _targetSize = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: Text(l10n.includeTimestampFilename),
                    value: _includeTimestamp,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setDialogState(() {
                        _includeTimestamp = value ?? false;
                      });
                      setState(() {
                        _includeTimestamp = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.fontStyleLabel),
                  const SizedBox(height: 12),
                  Text(
                    l10n.fontSelectionNote,
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewPanel(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: _processedFiles.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedPaths.isEmpty
                        ? l10n.emptyPreviewHint
                        : l10n.selectedPreviewHint,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  File(_currentProcessedFile!.sourcePath).uri.pathSegments.last,
                  style: theme.textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: PageView.builder(
                      itemCount: _processedFiles.length,
                      onPageChanged: (index) {
                        setState(() {
                          _previewIndex = index;
                        });
                        // Reset zoom when changing preview
                        _transformationController.value = Matrix4.identity();
                      },
                      itemBuilder: (context, index) {
                        final previewBytes = _processedFiles[index].result.previewBytes;
                        if (previewBytes == null) {
                          return Center(
                            child: Text(
                              l10n.previewUnavailable,
                              style: theme.textTheme.bodyMedium,
                            ),
                          );
                        }

                        return Stack(
                          children: [
                            GestureDetector(
                              onDoubleTap: () {
                                final currentScale = _transformationController.value.getMaxScaleOnAxis();
                                final targetScale = currentScale > 1.0 ? 1.0 : 2.0;
                                
                                if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
                                  HapticFeedback.lightImpact();
                                }
                                
                                _transformationController.value = Matrix4.identity()..scale(targetScale);
                              },
                              child: InteractiveViewer(
                                transformationController: _transformationController,
                                minScale: 0.5,
                                maxScale: 4.0,
                                panEnabled: true,
                                scaleEnabled: true,
                                child: Center(
                                  child: Image.memory(
                                    previewBytes, 
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            // Zoom instructions overlay (shows when not zoomed)
                            ValueListenableBuilder<Matrix4>(
                              valueListenable: _transformationController,
                              builder: (context, matrix, child) {
                                final scale = matrix.getMaxScaleOnAxis();
                                final isZoomed = scale > 1.0;
                                final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                                
                                return Positioned(
                                  top: isMobile ? 12 : 8,
                                  left: 8,
                                  right: 8,
                                  child: AnimatedOpacity(
                                    opacity: isZoomed ? 0.0 : (isMobile ? 0.8 : 0.7),
                                    duration: const Duration(milliseconds: 300),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 16 : 12,
                                        vertical: isMobile ? 12 : 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(isMobile ? 20 : 16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.pinch, 
                                            color: Colors.white, 
                                            size: isMobile ? 20 : 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isMobile 
                                                ? 'Pinch or double-tap to zoom'
                                                : 'Pinch to zoom • Double-tap to zoom',
                                            style: (isMobile 
                                                ? theme.textTheme.bodyMedium 
                                                : theme.textTheme.bodySmall)?.copyWith(
                                              color: Colors.white,
                                              fontWeight: isMobile ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Reset zoom button (only visible when zoomed)
                            ValueListenableBuilder<Matrix4>(
                              valueListenable: _transformationController,
                              builder: (context, matrix, child) {
                                final scale = matrix.getMaxScaleOnAxis();
                                if (scale <= 1.0) return const SizedBox.shrink();
                                
                                return Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: FloatingActionButton.small(
                                    heroTag: "zoom_reset_$index", // Unique hero tag for PageView
                                    onPressed: () {
                                      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
                                        HapticFeedback.lightImpact();
                                      }
                                      _transformationController.value = Matrix4.identity();
                                    },
                                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
                                    child: const Icon(Icons.zoom_out_map, size: 20),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                if (_processedFiles.length > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.swipeHint(_previewIndex + 1, _processedFiles.length),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildLoadingOverlay(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final message = _progressMessage.isEmpty 
        ? (_statusMessage.isEmpty ? l10n.processingFile : _statusMessage)
        : _progressMessage;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.18),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    value: _progress > 0 ? _progress : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.applyingWatermark, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if (_progress > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _cancelProcessing,
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorFooter(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Text(
      l10n.authorFooter,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall,
    );
  }

  Widget _buildPrimaryActionCard() {
    final l10n = AppLocalizations.of(context)!;
    final selectedCount = _selectedPaths.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _processing ? null : _pickFile,
              icon: const Icon(Icons.file_open),
              label: Text(l10n.pickFiles),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
            if (selectedCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                selectedCount == 1
                    ? l10n.selectedFile(File(_selectedPaths.first).uri.pathSegments.last)
                    : l10n.selectedFiles(selectedCount),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _processing || _selectedPaths.isEmpty ? null : _applyWatermark,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(l10n.applyWatermark),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
            // Hide Save button on mobile platforms (iOS/Android)
            if (!isMobile)
              FilledButton.icon(
                onPressed: _processing || _processedFiles.isEmpty ? null : _saveCurrent,
                icon: const Icon(Icons.save_alt),
                label: Text(l10n.saveAll),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                ),
              ),
            FilledButton.icon(
              onPressed: _processing || _processedFiles.isEmpty ? null : _shareCurrent,
              icon: const Icon(Icons.share_outlined),
              label: Text(l10n.shareAll),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _processing ? null : _reset,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reset),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextCard() {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _textController,
          enabled: !_processing,
          decoration: InputDecoration(
            labelText: l10n.watermarkTextLabel,
            hintText: l10n.watermarkTextHint,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildColorCard() {
    final l10n = AppLocalizations.of(context)!;
    const palette = <Color>[
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
      Colors.yellow,
      Colors.white,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final selectionControls = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment<bool>(value: true, label: Text(l10n.randomColor)),
                    ButtonSegment<bool>(value: false, label: Text(l10n.selectedColor)),
                  ],
                  selected: <bool>{_useRandomColor},
                  onSelectionChanged: _processing
                      ? null
                      : (selection) {
                          _updateColorMode(selection.first);
                        },
                ),
                if (!_useRandomColor) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: palette.map((color) {
                      final isSelected = color.value == _selectedColor.value;
                      return InkWell(
                        onTap: _processing
                            ? null
                            : () => _selectColor(color),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.grey.shade400,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );

            final sliders = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTransparencyControl(),
                const SizedBox(height: 18),
                _buildDensityControl(),
              ],
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: selectionControls),
                  const SizedBox(width: 20),
                  SizedBox(width: 220, child: sliders),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                selectionControls,
                const SizedBox(height: 16),
                sliders,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransparencyControl() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.transparencyValue(_transparency.round())),
        Slider(
          value: _transparency,
          min: 10,
          max: 90,
          divisions: 80,
          onChanged: _processing
              ? null
              : (value) {
                  setState(() {
                    _transparency = value;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildDensityControl() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.densityValue(_density.round())),
        Slider(
          value: _density,
          min: 20,
          max: 100,
          divisions: 16,
          onChanged: _processing
              ? null
              : (value) {
                  setState(() {
                    _density = value;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildDropArea(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragging = false;
        });
      },
      onDragDone: (detail) async {
        setState(() {
          _dragging = false;
        });

        if (detail.files.isEmpty) {
          return;
        }

        final paths = detail.files
            .map((file) => file.path)
            .whereType<String>()
            .toSet()
            .toList();
        if (paths.isEmpty) {
          setState(() {
            _statusMessage = l10n.droppedPathUnavailable;
          });
          return;
        }

        _selectPaths(paths);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _dragging ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _dragging ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.file_upload_outlined, size: 36),
            const SizedBox(height: 10),
            Text(l10n.desktopDropArea),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context)!;

    final group = XTypeGroup(
      label: l10n.pickerLabel,
      extensions: <String>['jpg', 'jpeg', 'png', 'pdf'],
      uniformTypeIdentifiers: <String>['public.jpeg', 'public.png', 'com.adobe.pdf'],
    );

    final files = await openFiles(acceptedTypeGroups: <XTypeGroup>[group]);
    if (files.isEmpty) {
      return;
    }

    _selectPaths(files.map((file) => file.path).toList());
  }

  void _selectPaths(List<String> paths) {
    final l10n = AppLocalizations.of(context)!;
    final uniquePaths = paths.toSet().toList();

    setState(() {
      _selectedPaths = uniquePaths;
      _processedFiles = <_ProcessedFile>[];
      _previewIndex = 0;
      _statusMessage = uniquePaths.length == 1
          ? l10n.selectedApplySingle(File(uniquePaths.first).uri.pathSegments.last)
          : l10n.selectedApplyMultiple(uniquePaths.length);
    });
  }

  Future<void> _processPaths(List<String> paths) async {
    final l10n = AppLocalizations.of(context)!;

    _cancellationToken = CancellationToken();

    setState(() {
      _processing = true;
      _processedFiles = <_ProcessedFile>[];
      _previewIndex = 0;
      _progress = 0.0;
      _progressMessage = '';
      _statusMessage = l10n.processingCount(paths.length);
    });

    final processedFiles = <_ProcessedFile>[];
    final failedFiles = <String>[];

    try {
      for (var i = 0; i < paths.length; i++) {
        if (_cancellationToken?.isCancelled == true) {
          setState(() {
            _processing = false;
            _progress = 0.0;
            _progressMessage = '';
            _statusMessage = 'Processing cancelled';
          });
          return;
        }

        final path = paths[i];

        if (!mounted) {
          return;
        }

        try {
          final result = await WatermarkProcessor.processFile(
            file: File(path),
            transparency: _transparency,
            density: _density,
            watermarkText: _textController.text,
            useRandomColor: _useRandomColor,
            selectedColorValue: _selectedColor.toARGB32(),
            fontSize: _fontSize,
            jpegQuality: _jpegQuality,
            targetSize: _targetSize,
            includeTimestamp: _includeTimestamp,
            onProgress: (progress, message) {
              if (mounted) {
                setState(() {
                  final fileProgress = i / paths.length;
                  _progress = fileProgress + (progress / paths.length);
                  _progressMessage = message;
                });
              }
            },
            cancellationToken: _cancellationToken,
          );

          processedFiles.add(_ProcessedFile(sourcePath: path, result: result));
        } catch (e) {
          failedFiles.add(path);
          print('Failed to process $path: $e');
          
          // Show user-friendly error message if it's a WatermarkError
          if (e is WatermarkError && mounted) {
            setState(() {
              _statusMessage = e.userMessage;
            });
          }
        }
      }

      if (!mounted) {
        return;
      }

      if (processedFiles.isEmpty && failedFiles.isNotEmpty) {
        setState(() {
          _statusMessage = failedFiles.length == 1 
              ? 'Failed to process file. Please check the file format and try again.'
              : 'Failed to process ${failedFiles.length} files. Please check the file formats and try again.';
          _processing = false;
          _progress = 0.0;
          _progressMessage = '';
        });
        return;
      }

      final successMessage = processedFiles.isEmpty
          ? l10n.processingFailed
          : failedFiles.isEmpty
              ? l10n.previewReady(processedFiles.length)
              : 'Processed ${processedFiles.length} files successfully. ${failedFiles.length} files failed.';

      setState(() {
        _processedFiles = processedFiles;
        _previewIndex = 0;
        _statusMessage = successMessage;
        _processing = false;
        _progress = 1.0;
        _progressMessage = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      String errorMessage;
      if (error is WatermarkError) {
        errorMessage = error.userMessage;
      } else {
        errorMessage = l10n.errorPrefix(error.toString());
      }

      setState(() {
        _statusMessage = errorMessage;
        _processing = false;
        _progress = 0.0;
        _progressMessage = '';
      });
    }
  }

  void _cancelProcessing() {
    _cancellationToken?.cancel();
    setState(() {
      _processing = false;
      _progress = 0.0;
      _progressMessage = '';
      _statusMessage = 'Processing cancelled';
    });
  }

  void _reset() {
    _cancellationToken?.cancel();
    setState(() {
      _dragging = false;
      _processing = false;
      _progress = 0.0;
      _progressMessage = '';
      _selectedPaths = <String>[];
      _processedFiles = <_ProcessedFile>[];
      _previewIndex = 0;
      _statusMessage = '';
      _cancellationToken = null;
    });
  }

  Future<void> _applyWatermark() async {
    if (_selectedPaths.isEmpty) {
      return;
    }
    await _processPaths(_selectedPaths);
  }

  Future<void> _saveCurrent() async {
    final l10n = AppLocalizations.of(context)!;

    if (_processedFiles.isEmpty) {
      return;
    }

    setState(() {
      _statusMessage = 'Saving files...';
    });

    final savedFiles = <String>[];
    final failedFiles = <String>[];

    try {
      for (final file in _processedFiles) {
        try {
          // Create the directory if it doesn't exist
          final outputFile = File(file.result.outputPath);
          final directory = outputFile.parent;
          
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          
          await outputFile.writeAsBytes(file.result.outputBytes);
          savedFiles.add(file.result.outputPath);
        } catch (e) {
          failedFiles.add(file.sourcePath);
          print('Failed to save ${file.result.outputPath}: $e');
        }
      }

      if (!mounted) {
        return;
      }

      // Provide detailed feedback about save results
      String statusMessage;
      if (failedFiles.isEmpty) {
        statusMessage = savedFiles.length == 1
            ? 'File saved to: ${_getDisplayPath(savedFiles.first)}'
            : l10n.savedFiles(savedFiles.length);
      } else if (savedFiles.isEmpty) {
        statusMessage = 'Failed to save files. Please check permissions and storage space.';
      } else {
        statusMessage = 'Saved ${savedFiles.length} files. ${failedFiles.length} files failed.';
      }

      setState(() {
        _statusMessage = statusMessage;
      });

      // Show a more detailed dialog with save locations
      if (savedFiles.isNotEmpty && mounted) {
        _showSaveResultDialog(savedFiles, failedFiles);
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _statusMessage = 'Error saving files: ${e.toString()}';
      });
    }
  }

  /// Get save location information for display
  String _getSaveLocationInfo() {
    if (_processedFiles.isEmpty) return '';
    
    final firstFile = _processedFiles.first;
    final directory = p.dirname(firstFile.sourcePath);
    final displayDir = p.basename(directory);
    
    if (_processedFiles.length == 1) {
      final fileName = p.basenameWithoutExtension(firstFile.result.outputPath);
      return 'Will save as: $fileName in $displayDir/';
    } else {
      return 'Will save ${_processedFiles.length} files to: $displayDir/';
    }
  }

  /// Get a user-friendly display path
  String _getDisplayPath(String fullPath) {
    if (fullPath.length > 50) {
      final fileName = p.basename(fullPath);
      final directory = p.basename(p.dirname(fullPath));
      return '.../$directory/$fileName';
    }
    return fullPath;
  }

  /// Show detailed save results dialog
  void _showSaveResultDialog(List<String> savedFiles, List<String> failedFiles) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Files Saved'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (savedFiles.isNotEmpty) ...[
                Text('✅ Successfully saved ${savedFiles.length} files:'),
                const SizedBox(height: 8),
                ...savedFiles.map((path) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Text(
                    _getDisplayPath(path),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )),
              ],
              if (failedFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('❌ Failed to save ${failedFiles.length} files:'),
                const SizedBox(height: 8),
                ...failedFiles.map((path) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Text(
                    p.basename(path),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareCurrent() async {
    final l10n = AppLocalizations.of(context)!;

    if (_processedFiles.isEmpty) {
      return;
    }

    for (final file in _processedFiles) {
      await File(file.result.outputPath).writeAsBytes(file.result.outputBytes);
    }

    final shareFiles = _processedFiles
        .map(
          (file) => XFile(
            file.result.outputPath,
            mimeType: _mimeTypeForPath(file.result.outputPath),
          ),
        )
        .toList();

    final result = await SharePlus.instance.share(
      ShareParams(
        files: shareFiles,
        subject: l10n.shareSubject,
        text: l10n.shareText,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = result.status == ShareResultStatus.success
          ? l10n.sharedFiles(_processedFiles.length)
          : l10n.shareOpenedFiles(_processedFiles.length);
    });
  }

  String _mimeTypeForPath(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  void _updateColorMode(bool useRandomColor) {
    setState(() {
      _useRandomColor = useRandomColor;
    });
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
    });
  }
}
