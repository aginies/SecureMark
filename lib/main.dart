import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_localizations.dart';
import 'watermark_processor.dart';
import 'font_manager.dart';

class WatermarkShaderPainter extends CustomPainter {
  WatermarkShaderPainter({
    required this.shader,
    required this.image,
    required this.color,
    required this.transparency,
  });

  final ui.FragmentShader shader;
  final ui.Image image;
  final Color color;
  final double transparency;

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, color.red / 255);
    shader.setFloat(3, color.green / 255);
    shader.setFloat(4, color.blue / 255);
    shader.setFloat(5, color.opacity);
    shader.setFloat(6, transparency / 100);
    shader.setImageSampler(0, image);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant WatermarkShaderPainter oldDelegate) {
    return oldDelegate.color != color || 
           oldDelegate.transparency != transparency ||
           oldDelegate.image != image;
  }
}

class _ProcessedFile {
  const _ProcessedFile({
    required this.sourcePath,
    required this.result,
  });

  final String sourcePath;
  final ProcessResult result;
}

void main() {
  runApp(const SecureMarkApp());
}

class SecureMarkApp extends StatelessWidget {
  const SecureMarkApp({super.key});

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

class _WatermarkPageState extends State<WatermarkPage> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final TransformationController _transformationController = TransformationController();
  final PageController _previewController = PageController();
  double _transparency = 75;
  double _density = 35;
  double _fontSize = 24;
  WatermarkFont _selectedFont = FontManager.getDefaultFont();
  int _jpegQuality = 75;
  int? _targetSize = 1280;
  bool _includeTimestamp = true;
  bool _preserveMetadata = false;
  bool _rasterizePdf = false;
  String _filePrefix = 'securemark-';
  bool _useRandomColor = true;
  Color _selectedColor = Colors.red;
  bool _dragging = false;
  bool _processing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String _progressMessage = '';
  String _appVersion = '';
  String? _outputDirectory;
  ui.Image? _rawImage;
  final List<String> _logs = <String>[];
  final List<String> _tempFiles = <String>[];
  List<String> _selectedPaths = <String>[];
  ui.FragmentProgram? _shaderProgram;

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/watermark.frag');
      if (mounted) {
        setState(() {
          _shaderProgram = program;
        });
      }
    } catch (e) {
      _addLog('Failed to load shader: $e');
    }
  }

  Future<void> _cleanupTempFiles() async {
    if (_tempFiles.isEmpty) return;
    
    _addLog('Cleaning up ${_tempFiles.length} temporary files...');
    for (final path in _tempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        _addLog('Error deleting temp file $path: $e');
      }
    }
    _tempFiles.clear();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().split('.').first;
    final logEntry = '[$timestamp] $message';
    debugPrint(logEntry);
    setState(() {
      _logs.insert(0, logEntry);
      // Keep only last 100 logs
      if (_logs.length > 100) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _pickOutputDirectory() async {
    try {
      final String? directoryPath = await getDirectoryPath();
      if (directoryPath != null) {
        _addLog('Selected output directory: $directoryPath');
        setState(() {
          _outputDirectory = directoryPath;
        });
      }
    } catch (e) {
      _addLog('Error picking directory: $e');
    }
  }
  List<_ProcessedFile> _processedFiles = <_ProcessedFile>[];
  int _previewIndex = 0;
  CancellationToken? _cancellationToken;
  static const MethodChannel _platform = MethodChannel('secure_mark/sharing');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadShader();
    _handleSharedContent();
    _initPackageInfo();
    _initOutputDirectory();
  }

  Future<void> _initOutputDirectory() async {
    if (!kIsWeb && Platform.isMacOS) {
      try {
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          if (mounted) {
            setState(() {
              _outputDirectory = directory.path;
            });
          }
          _addLog('Default macOS output directory set to: ${directory.path}');
        }
      } catch (e) {
        _addLog('Error setting default macOS output directory: $e');
      }
    }
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  @override
  void dispose() {
    _cleanupTempFiles();
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _transformationController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check for shared content when app comes back to foreground
      _handleSharedContent();
    }
  }

  Future<void> _handleSharedContent() async {
    _addLog('Checking for shared content...');
    try {
      final List<dynamic>? sharedFiles = await _platform.invokeMethod('getSharedFiles');
      if (sharedFiles != null && sharedFiles.isNotEmpty) {
        _addLog('Received ${sharedFiles.length} shared files');
        final List<String> validFiles = sharedFiles
            .where((file) => file is String && File(file).existsSync())
            .map((file) => file as String)
            .where((path) {
          final extension = p.extension(path).toLowerCase();
          final isValid = ['.jpg', '.jpeg', '.png', '.webp', '.pdf', '.heic', '.heif'].contains(extension);
          if (!isValid) _addLog('Unsupported extension: $extension for file $path');
          return isValid;
        }).toList();

        if (validFiles.isNotEmpty) {
          _addLog('Found ${validFiles.length} valid shared files');
          // Reset the app state before processing new shared files
          _reset();
          
          setState(() {
            _selectedPaths = validFiles;
            _processedFiles.clear();
            _previewIndex = 0;
          });
        } else {
          _addLog('No valid shared files found');
        }
      } else {
        _addLog('No shared content received');
      }
    } catch (e) {
      _addLog('Error handling shared content: $e');
    }
  }

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
        child: LayoutBuilder(
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
          // Only show "Ready to save" message on desktop platforms where Save button is visible
          if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) ...[
            Text(
              l10n.readyToSaveFiles(_processedFiles.length),
              style: theme.textTheme.bodySmall,
            ),
          ],
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
      ],
    );
  }

  void _showLogs() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.appLogs),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: _logs.isEmpty
                ? Center(child: Text(l10n.noLogsYet))
                : ListView.separated(
                    itemCount: _logs.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      return Text(
                        _logs[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
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
              content: SingleChildScrollView(
                child: Column(
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
                        DropdownMenuItem<int?>(value: 2048, child: Text(l10n.pixelUnit(2048))),
                        DropdownMenuItem<int?>(value: 1600, child: Text(l10n.pixelUnit(1600))),
                        DropdownMenuItem<int?>(value: 1280, child: Text(l10n.pixelUnit(1280))),
                        DropdownMenuItem<int?>(value: 1024, child: Text(l10n.pixelUnit(1024))),
                        DropdownMenuItem<int?>(value: 800, child: Text(l10n.pixelUnit(800))),
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
                    CheckboxListTile(
                      title: Text(l10n.preserveExifData),
                      value: _preserveMetadata,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(() {
                          _preserveMetadata = value ?? false;
                        });
                        setState(() {
                          _preserveMetadata = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(l10n.rasterizePdfTitle),
                      subtitle: Text(l10n.rasterizePdfSubtitle),
                      value: _rasterizePdf,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(() {
                          _rasterizePdf = value ?? false;
                        });
                        setState(() {
                          _rasterizePdf = value ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.fontStyleLabel),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<WatermarkFont>(
                          value: _selectedFont,
                          isExpanded: true,
                          onChanged: (WatermarkFont? newFont) {
                            if (newFont != null) {
                              setState(() {
                                _selectedFont = newFont;
                              });
                            }
                          },
                          items: _buildFontDropdownItems(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getFontSourceDescription(context),
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        l10n.outputDirectoryLabel(_outputDirectory ?? l10n.resizeNone),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _pickOutputDirectory();
                          setDialogState(() {}); // Update dialog state
                        },
                        icon: const Icon(Icons.folder_open),
                        label: Text(l10n.selectOutputDirectory),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showLogs();
                      },
                      icon: const Icon(Icons.list_alt),
                      label: Text(l10n.viewLogs),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('https://github.com/aginies/SecureMark')),
                      icon: const Icon(Icons.code),
                      label: Text(l10n.openGitHub),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ],
                ),
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
                  if (_rawImage != null && _shaderProgram != null) ...[
                    // Live Shader Preview!
                    SizedBox(
                      height: 250,
                      child: CustomPaint(
                        painter: WatermarkShaderPainter(
                          shader: _shaderProgram!.fragmentShader(),
                          image: _rawImage!,
                          color: _useRandomColor ? Colors.deepPurple : _selectedColor,
                          transparency: _transparency,
                        ),
                        child: Container(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.selectedPreviewHint,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
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
                      controller: _previewController,
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
                                // Smart zoom: cycle through 1.0 -> 2.0 -> 3.0 -> 1.0
                                final targetScale = currentScale <= 1.0 
                                    ? 2.0 
                                    : currentScale <= 2.0 
                                        ? 3.0 
                                        : 1.0;
                                
                                if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
                                  HapticFeedback.lightImpact();
                                }
                                
                                _transformationController.value = Matrix4.diagonal3Values(targetScale, targetScale, 1.0);
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
                            // Navigation arrows for Desktop
                            if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS) && _processedFiles.length > 1) ...[
                              Positioned(
                                left: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: IconButton.filledTonal(
                                    onPressed: _previewIndex > 0 
                                        ? () => _previewController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: IconButton.filledTonal(
                                    onPressed: _previewIndex < _processedFiles.length - 1
                                        ? () => _previewController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildAuthorFooter(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(
          l10n.authorFooter,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (_appVersion.isNotEmpty)
          Text(
            'v$_appVersion',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
      ],
    );
  }

  Widget _buildPrimaryActionCard() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selectedCount = _selectedPaths.length;

    Widget buildButton(bool isDragging) {
      return FilledButton(
        onPressed: _processing ? null : _pickFile,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 24),
          backgroundColor: isDragging ? theme.colorScheme.primary.withValues(alpha: 0.8) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isDragging 
                ? BorderSide(color: theme.colorScheme.onPrimary, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDragging ? Icons.file_upload : Icons.file_upload_outlined, 
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.pickFiles,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_supportsDesktopDrop)
              DropTarget(
                onDragEntered: (_) => setState(() => _dragging = true),
                onDragExited: (_) => setState(() => _dragging = false),
                onDragDone: (detail) async {
                  setState(() => _dragging = false);
                  if (detail.files.isEmpty) return;
                  final paths = detail.files
                      .map((file) => file.path)
                      .whereType<String>()
                      .toSet()
                      .toList();
                  if (paths.isNotEmpty) _selectPaths(paths);
                },
                child: buildButton(_dragging),
              )
            else
              buildButton(false),
            if (selectedCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                selectedCount == 1
                    ? l10n.selectedFile(File(_selectedPaths.first).uri.pathSegments.last)
                    : l10n.selectedFiles(selectedCount),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
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
      Colors.purple,
      Colors.black,
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
                      final isSelected = color.toARGB32() == _selectedColor.toARGB32();
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

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context)!;

    final group = XTypeGroup(
      label: l10n.pickerLabel,
      extensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf', 'heic', 'heif'],
      uniformTypeIdentifiers: const <String>['public.jpeg', 'public.png', 'public.webp', 'com.adobe.pdf', 'public.heic', 'public.heif'],
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
      _rawImage = null; // Clear old image
      _statusMessage = uniquePaths.length == 1
          ? l10n.selectedApplySingle(File(uniquePaths.first).uri.pathSegments.last)
          : l10n.selectedApplyMultiple(uniquePaths.length);
    });

    // Load the first image for live shader preview
    if (uniquePaths.isNotEmpty) {
      final firstPath = uniquePaths.first;
      final extension = p.extension(firstPath).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
        File(firstPath).readAsBytes().then((bytes) {
          ui.decodeImageFromList(bytes, (image) {
            if (mounted) {
              setState(() {
                _rawImage = image;
              });
            }
          });
        });
      }
    }
  }

  Future<void> _processPaths(List<String> paths) async {
    if (_processing || paths.isEmpty) return;
    
    _addLog('Processing ${paths.length} paths');
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    _cancellationToken = CancellationToken();

    setState(() {
      _processing = true;
      _processedFiles = <_ProcessedFile>[];
      _previewIndex = 0;
      _progress = 0.0;
      _progressMessage = '';
      _statusMessage = l10n.processingCount(paths.length);
    });

    await _cleanupTempFiles();

    final processedFiles = <_ProcessedFile>[];
    final failedFiles = <String>[];
    bool dialogOpened = false;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        dialogOpened = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Internal progress listener to trigger dialog rebuilds
            _progressListener = () {
              if (context.mounted) setDialogState(() {});
            };
            
            final message = _progressMessage.isEmpty 
                ? (_statusMessage.isEmpty ? l10n.processingFile : _statusMessage)
                : _progressMessage;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      value: _progress > 0 ? _progress : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.applyingWatermark, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_progress > 0) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).round()}${Localizations.localeOf(context).languageCode == 'fr' ? ' %' : '%'}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _cancelProcessing,
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      for (var i = 0; i < paths.length; i++) {
        if (_cancellationToken?.isCancelled == true) {
          _addLog('Processing cancelled by user');
          break;
        }

        final path = paths[i];
        final fileName = p.basename(path);

        if (!mounted) break;

        _addLog('Starting file $i: $fileName');
        
        setState(() {
          _statusMessage = l10n.processingNamedFile(i + 1, paths.length, fileName);
        });
        _progressListener?.call();

        try {
          final result = await WatermarkProcessor.processFile(
            file: File(path),
            transparency: _transparency,
            density: _density,
            watermarkText: _textController.text,
            useRandomColor: _useRandomColor,
            selectedColorValue: _selectedColor.toARGB32(),
            fontSize: _fontSize,
            font: _selectedFont,
            jpegQuality: _jpegQuality,
            targetSize: _targetSize,
            includeTimestamp: _includeTimestamp,
            preserveMetadata: _preserveMetadata,
            rasterizePdf: _rasterizePdf,
            onProgress: (progress, message) {
              if (mounted) {
                setState(() {
                  final fileProgress = i / paths.length;
                  _progress = fileProgress + (progress / paths.length);
                  _progressMessage = message;
                });
                _progressListener?.call();
              }
            },
            cancellationToken: _cancellationToken,
          );

          _addLog('Successfully processed $fileName');
          processedFiles.add(_ProcessedFile(sourcePath: path, result: result));
        } catch (e) {
          _addLog('Failed to process $fileName: $e');
          failedFiles.add(path);
          
          if (mounted) {
            setState(() {
              _statusMessage = e is WatermarkError ? e.userMessage : l10n.errorPrefix(e.toString());
            });
            _progressListener?.call();
          }
        }
      }
    } finally {
      // Close dialog when done or cancelled
      if (mounted && dialogOpened) {
        // Use the root navigator to be sure we're popping the dialog
        Navigator.of(context, rootNavigator: true).pop();
      }
      _progressListener = null;

      if (mounted) {
        if (_cancellationToken?.isCancelled == true) {
          setState(() {
            _processing = false;
            _progress = 0.0;
            _progressMessage = '';
            _statusMessage = l10n.processingCancelled;
          });
        } else {
          final successMessage = processedFiles.isEmpty
              ? l10n.processingFailed
              : failedFiles.isEmpty
                  ? (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                      ? l10n.previewReadyMobile(processedFiles.length)
                      : l10n.previewReady(processedFiles.length)
                  : l10n.processingStatusMultiple(processedFiles.length, failedFiles.length);

          setState(() {
            _processedFiles = processedFiles;
            _previewIndex = 0;
            _statusMessage = successMessage;
            _processing = false;
            _progress = 1.0;
            _progressMessage = '';
          });

          if (_previewController.hasClients) {
            _previewController.jumpToPage(0);
          }
        }
      }
    }
  }

  VoidCallback? _progressListener;

  void _cancelProcessing() {
    final l10n = AppLocalizations.of(context)!;
    _cancellationToken?.cancel();
    setState(() {
      _processing = false;
      _progress = 0.0;
      _progressMessage = '';
      _statusMessage = l10n.processingCancelled;
    });
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _reset() {
    _cancellationToken?.cancel();
    if (_previewController.hasClients) {
      _previewController.jumpToPage(0);
    }
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
      _statusMessage = l10n.savingFiles;
    });

    final savedFiles = <String>[];
    final failedFiles = <String>[];

    try {
      for (final file in _processedFiles) {
        try {
          String outputPath = file.result.outputPath;
          
          // If a custom output directory is selected (Desktop only), use it
          if (_outputDirectory != null) {
            final fileName = p.basename(file.result.outputPath);
            outputPath = p.join(_outputDirectory!, fileName);
          }

          final outputFile = File(outputPath);
          final directory = outputFile.parent;
          
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          
          await outputFile.writeAsBytes(file.result.outputBytes);
          savedFiles.add(outputPath);
        } catch (e) {
          failedFiles.add(file.sourcePath);
          final logPath = _outputDirectory ?? p.dirname(file.result.outputPath);
          _addLog('Failed to save to $logPath: $e');
        }
      }

      if (!mounted) {
        return;
      }

      // Provide detailed feedback about save results
      String statusMessage;
      if (failedFiles.isEmpty) {
        statusMessage = savedFiles.length == 1
            ? l10n.fileSavedTo(_getDisplayPath(savedFiles.first))
            : l10n.savedFiles(savedFiles.length);
      } else if (savedFiles.isEmpty) {
        statusMessage = l10n.saveFailedGeneral;
      } else {
        statusMessage = l10n.saveStatusMultiple(savedFiles.length, failedFiles.length);
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
        _statusMessage = l10n.errorSavingFiles(e.toString());
      });
    }
  }

  /// Get save location information for display
  String _getSaveLocationInfo() {
    final l10n = AppLocalizations.of(context)!;
    if (_processedFiles.isEmpty) return '';
    
    final firstFile = _processedFiles.first;
    final directory = _outputDirectory ?? p.dirname(firstFile.sourcePath);
    final displayDir = _outputDirectory != null ? _outputDirectory! : p.basename(directory);
    
    // For long paths, show a shortened version
    final displayPath = displayDir.length > 40 
        ? '...${displayDir.substring(displayDir.length - 37)}' 
        : displayDir;
    
    if (_processedFiles.length == 1) {
      final fileName = p.basenameWithoutExtension(firstFile.result.outputPath);
      return l10n.willSaveAsIn(fileName, displayPath);
    } else {
      return l10n.willSaveMultipleIn(_processedFiles.length, displayPath);
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filesSavedTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (savedFiles.isNotEmpty) ...[
                Text('✅ ${l10n.successfullySavedCount(savedFiles.length)}'),
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
                Text('❌ ${l10n.failedSavedCount(failedFiles.length)}'),
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
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _shareCurrent() async {
    final l10n = AppLocalizations.of(context)!;
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    if (_processedFiles.isEmpty) {
      return;
    }

    final shareFiles = <XFile>[];
    for (final file in _processedFiles) {
      String outputPath = file.result.outputPath;
      if (_outputDirectory != null) {
        final fileName = p.basename(file.result.outputPath);
        outputPath = p.join(_outputDirectory!, fileName);
      }
      
      final directory = p.dirname(outputPath);
      if (!await Directory(directory).exists()) {
        await Directory(directory).create(recursive: true);
      }

      await File(outputPath).writeAsBytes(file.result.outputBytes);
      _tempFiles.add(outputPath);
      shareFiles.add(XFile(
        outputPath,
        mimeType: _mimeTypeForPath(outputPath),
      ));
    }

    final result = await SharePlus.instance.share(
      ShareParams(
        files: shareFiles,
        subject: l10n.shareSubject,
        text: l10n.shareText,
        sharePositionOrigin: sharePositionOrigin,
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
      '.webp' => 'image/webp',
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

  List<DropdownMenuItem<WatermarkFont>> _buildFontDropdownItems() {
    final items = <DropdownMenuItem<WatermarkFont>>[];
    
    // Add system/bitmap fonts
    final bitmapFonts = FontManager.bitmapFonts;
    if (bitmapFonts.isNotEmpty) {
      for (final font in bitmapFonts) {
        items.add(DropdownMenuItem<WatermarkFont>(
          value: font,
          child: Text(
            font.displayName,
            style: font.getTextStyle(fontSize: 14),
          ),
        ));
      }
    }
    
    // Add asset fonts if any exist
    final assetFonts = FontManager.assetFonts;
    if (assetFonts.isNotEmpty) {
      // Add a separator comment (not visible in dropdown but helps organization)
      for (final font in assetFonts) {
        items.add(DropdownMenuItem<WatermarkFont>(
          value: font,
          child: Text(
            font.displayName,
            style: font.getTextStyle(fontSize: 14),
          ),
        ));
      }
    }
    
    // Add Google fonts
    final googleFonts = FontManager.googleFonts;
    if (googleFonts.isNotEmpty) {
      for (final font in googleFonts) {
        items.add(DropdownMenuItem<WatermarkFont>(
          value: font,
          child: Text(
            font.displayName,
            style: font.getTextStyle(fontSize: 14),
          ),
        ));
      }
    }
    
    return items;
  }

  String _getFontSourceDescription(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_selectedFont.source) {
      case FontSource.bitmap:
        return l10n.fontSelectionNote;
      case FontSource.google:
        return l10n.fontSelectionNoteGoogle;
      case FontSource.asset:
        return l10n.fontSelectionNoteAsset;
    }
  }
}
