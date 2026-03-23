import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_localizations.dart';
import 'watermark_processor.dart';
import 'font_manager.dart';
import 'qr_config.dart';

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
    shader.setFloat(2, color.r);
    shader.setFloat(3, color.g);
    shader.setFloat(4, color.b);
    shader.setFloat(5, color.a);
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

class _WatermarkPageState extends State<WatermarkPage>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _qrAuthorController = TextEditingController();
  final TextEditingController _qrUrlController = TextEditingController();
  final TextEditingController _vCardFirstNameController =
      TextEditingController();
  final TextEditingController _vCardLastNameController =
      TextEditingController();
  final TextEditingController _vCardPhoneController = TextEditingController();
  final TextEditingController _vCardEmailController = TextEditingController();
  final TextEditingController _vCardOrgController = TextEditingController();
  final TextEditingController _hidingPasswordController =
      TextEditingController();
  final TextEditingController _extractionPasswordController =
      TextEditingController();
  final TextEditingController _filePrefixController = TextEditingController();
  final TransformationController _transformationController =
      TransformationController();
  final PageController _previewController = PageController();
  double _transparency = 75;
  double _density = 35;
  double _fontSize = 24;
  WatermarkFont _selectedFont = FontManager.getDefaultFont();
  int _jpegQuality = 75;
  int? _targetSize;
  bool _includeTimestamp = true;
  bool _preserveMetadata = false;
  bool _rasterizePdf = false;
  String _filePrefix = 'securemark-';
  double _antiAiLevel = 50.0;
  bool _useSteganography = false;
  bool _useRobustSteganography = false;
  bool _steganographyVerificationFailed = false;
  bool _useRandomColor = true;
  Color _selectedColor = Colors.red;
  bool _dragging = false;
  bool _processing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String _progressMessage = '';
  String _elapsedTime = '00:00';
  String _appVersion = '';
  String? _outputDirectory;
  ui.Image? _rawImage;
  final List<String> _logs = <String>[];
  final List<String> _tempFiles = <String>[];
  List<String> _selectedPaths = <String>[];
  ui.FragmentProgram? _shaderProgram;
  Stopwatch? _stopwatch;
  Timer? _timer;
  bool _showOriginalPreview = false;
  bool _hideFileWithSteganography = false;
  Uint8List? _hiddenFileBytes;
  String? _hiddenFileName;
  String _hidingPassword = '';
  String _extractionPassword = '';
  bool _zipOutputs = false;

  // QR Code Configuration
  bool _qrVisible = false;
  QrType _qrType = QrType.metadata;
  String _qrAuthor = '';
  String _qrUrl = '';
  String _vCardFirstName = '';
  String _vCardLastName = '';
  String _vCardPhone = '';
  String _vCardEmail = '';
  String _vCardOrg = '';
  QrPosition _qrPosition = QrPosition.bottomRight;
  double _qrSize = 100.0;
  double _qrOpacity = 0.8;

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('shaders/watermark.frag');
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

    // Safety check for mounted before setState, but always update the list
    _logs.insert(0, logEntry);
    if (_logs.length > 100) {
      _logs.removeLast();
    }

    if (mounted) {
      setState(() {});
    }
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
  Timer? _shareCheckTimer1;
  Timer? _shareCheckTimer2;

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _transparency = prefs.getDouble('transparency') ?? 75.0;
          _density = prefs.getDouble('density') ?? 35.0;
          _fontSize = prefs.getDouble('fontSize') ?? 24.0;
          _jpegQuality = prefs.getInt('jpegQuality') ?? 75;
          _targetSize = prefs.getInt('targetSize');
          if (prefs.containsKey('targetSizeIsNull') &&
              prefs.getBool('targetSizeIsNull') == true) {
            _targetSize = null;
          }
          _includeTimestamp = prefs.getBool('includeTimestamp') ?? true;
          _preserveMetadata = prefs.getBool('preserveMetadata') ?? false;
          _rasterizePdf = prefs.getBool('rasterizePdf') ?? false;
          _filePrefix = prefs.getString('filePrefix') ?? 'securemark-';
          _antiAiLevel = prefs.getDouble('antiAiLevel') ?? 50.0;
          _useSteganography = prefs.getBool('useSteganography') ?? false;
          _useRobustSteganography =
              prefs.getBool('useRobustSteganography') ?? false;
          _hideFileWithSteganography =
              prefs.getBool('hideFileWithSteganography') ?? false;
          _zipOutputs = prefs.getBool('zipOutputs') ?? false;
          _useRandomColor = prefs.getBool('useRandomColor') ?? true;
          _filePrefix = prefs.getString('filePrefix') ?? 'securemark-';
          _filePrefixController.text = _filePrefix;

          final colorValue = prefs.getInt('selectedColor');
          if (colorValue != null) {
            _selectedColor = Color(colorValue);
          }
          final fontFamily = prefs.getString('selectedFont');
          if (fontFamily != null) {
            try {
              _selectedFont = WatermarkFont.values
                  .firstWhere((f) => f.fontFamily == fontFamily);
            } catch (_) {
              // Keep default if not found
            }
          }

          // Load QR watermark preferences
          _qrVisible = prefs.getBool('qrVisible') ?? false;
          final qrTypeIndex = prefs.getInt('qrType');
          if (qrTypeIndex != null &&
              qrTypeIndex >= 0 &&
              qrTypeIndex < QrType.values.length) {
            _qrType = QrType.values[qrTypeIndex];
          }
          _qrAuthor = prefs.getString('qrAuthor') ?? '';
          _qrUrl = prefs.getString('qrUrl') ?? '';
          _vCardFirstName = prefs.getString('vCardFirstName') ?? '';
          _vCardLastName = prefs.getString('vCardLastName') ?? '';
          _vCardPhone = prefs.getString('vCardPhone') ?? '';
          _vCardEmail = prefs.getString('vCardEmail') ?? '';
          _vCardOrg = prefs.getString('vCardOrg') ?? '';

          _qrAuthorController.text = _qrAuthor;
          _qrUrlController.text = _qrUrl;
          _vCardFirstNameController.text = _vCardFirstName;
          _vCardLastNameController.text = _vCardLastName;
          _vCardPhoneController.text = _vCardPhone;
          _vCardEmailController.text = _vCardEmail;
          _vCardOrgController.text = _vCardOrg;

          _qrSize = prefs.getDouble('qrSize') ?? 100.0;
          _qrOpacity = prefs.getDouble('qrOpacity') ?? 0.8;
          final qrPosIndex = prefs.getInt('qrPosition');
          if (qrPosIndex != null &&
              qrPosIndex >= 0 &&
              qrPosIndex < QrPosition.values.length) {
            _qrPosition = QrPosition.values[qrPosIndex];
          }

          _hidingPassword = prefs.getString('hidingPassword') ?? '';
          _hidingPasswordController.text = _hidingPassword;

          _hiddenFileName = prefs.getString('hiddenFileName');
          final hiddenFileB64 = prefs.getString('hiddenFileBytes');
          if (hiddenFileB64 != null) {
            try {
              _hiddenFileBytes = base64Decode(hiddenFileB64);
            } catch (_) {
              _hiddenFileBytes = null;
            }
          }
        });
      }
    } catch (e) {
      _addLog('Error loading preferences: $e');
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value == null) {
        if (key == 'targetSize') {
          await prefs.setBool('targetSizeIsNull', true);
        }
        await prefs.remove(key);
      }
    } catch (e) {
      _addLog('Error saving preference $key: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupPlatformCallHandler();
    _loadPreferences();
    _loadShader();
    _initPackageInfo();
    _initOutputDirectory();

    // Check for shared content multiple times to handle race conditions
    _handleSharedContent();
    _shareCheckTimer1 = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _handleSharedContent();
    });
    _shareCheckTimer2 = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _handleSharedContent();
    });
  }

  void _setupPlatformCallHandler() {
    _addLog('📡 Setting up platform method call handler...');
    _platform.setMethodCallHandler((call) async {
      _addLog(
          '🔔 Received platform call: ${call.method} with arguments: ${call.arguments}');
      if (call.method == 'onSharedFilesReceived') {
        final fileCount = call.arguments;
        _addLog('⭐⭐⭐ SHARE NOTIFICATION: $fileCount files available');
        _addLog('⏳ Waiting 300ms for Android to finish...');
        await Future.delayed(const Duration(milliseconds: 300));
        _addLog('⏰ Calling _handleSharedContent()...');
        await _handleSharedContent();
        _addLog('✅ _handleSharedContent() completed');
      }
    });
    _addLog('✅ Platform method call handler ready');
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
    _addLog('App initialized: v$_appVersion');
  }

  @override
  void dispose() {
    _cleanupTempFiles();
    _shareCheckTimer1?.cancel();
    _shareCheckTimer2?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _qrAuthorController.dispose();
    _qrUrlController.dispose();
    _vCardFirstNameController.dispose();
    _vCardLastNameController.dispose();
    _vCardPhoneController.dispose();
    _vCardEmailController.dispose();
    _vCardOrgController.dispose();
    _hidingPasswordController.dispose();
    _extractionPasswordController.dispose();
    _filePrefixController.dispose();
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
    _addLog('🔍 Checking for shared content...');
    if (!mounted) {
      _addLog('⚠️ Widget not mounted, skipping share check');
      return;
    }

    try {
      final List<dynamic>? sharedFiles =
          await _platform.invokeMethod('getSharedFiles');
      _addLog('📦 getSharedFiles returned: ${sharedFiles?.length ?? 0} items');

      if (sharedFiles != null && sharedFiles.isNotEmpty) {
        _addLog(
            '📋 Processing ${sharedFiles.length} shared files from Android...');

        final List<String> validFiles = [];

        for (var i = 0; i < sharedFiles.length; i++) {
          final file = sharedFiles[i];
          _addLog('[$i] Checking item type: ${file.runtimeType}');

          if (file is! String) {
            _addLog('[$i] ❌ Skipping non-string item: $file');
            continue;
          }

          final filePath = file;
          _addLog('[$i] 📄 File path: $filePath');

          final fileExists = File(filePath).existsSync();
          _addLog('[$i] File exists: $fileExists');

          if (!fileExists) {
            _addLog('[$i] ❌ File does not exist');
            continue;
          }

          final extension = p.extension(filePath).toLowerCase();
          _addLog('[$i] Extension: $extension');

          final isValid = [
            '.jpg',
            '.jpeg',
            '.png',
            '.webp',
            '.pdf',
            '.heic',
            '.heif'
          ].contains(extension);

          _addLog('[$i] Extension valid: $isValid');

          if (!isValid) {
            _addLog('[$i] ❌ Unsupported extension');
            continue;
          }

          _addLog('[$i] ✅ VALID FILE - Adding to list');
          validFiles.add(filePath);
        }

        _addLog(
            '📊 Validation complete: ${validFiles.length}/${sharedFiles.length} files valid');

        if (validFiles.isNotEmpty) {
          _addLog('✅ Found ${validFiles.length} valid shared files');
          _addLog('📁 Files: ${validFiles.join(", ")}');

          // Reset the app state before processing new shared files
          _addLog('🔄 Calling _reset() to clear previous state...');
          await _reset();
          _addLog('🔄 Reset complete');

          if (mounted) {
            setState(() {
              _selectedPaths = validFiles;
              _processedFiles.clear();
              _previewIndex = 0;
            });
            _addLog(
                '🎯 State updated: ${_selectedPaths.length} files selected');
            _addLog('📍 Current _selectedPaths: ${_selectedPaths.join(", ")}');
          }

          _addLog('✨ Shared files loaded successfully');

          // Show user-friendly notification
          if (mounted) {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '📥 Received ${validFiles.length} file${validFiles.length > 1 ? 's' : ''} from sharing'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              _addLog('⚠️ Could not show snackbar: $e');
            }
          }
        } else {
          _addLog('❌ No valid shared files found after filtering');
          if (mounted && sharedFiles.isNotEmpty) {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '⚠️ Shared files are not in a supported format (JPG, PNG, WebP, PDF, HEIC/HEIF)'),
                  duration: Duration(seconds: 4),
                  backgroundColor: Colors.orange,
                ),
              );
            } catch (e) {
              _addLog('⚠️ Could not show error snackbar: $e');
            }
          }
        }
      } else {
        _addLog('No shared content available');
      }
    } catch (e, stackTrace) {
      _addLog('Error handling shared content: $e');
      _addLog('Stack trace: $stackTrace');
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
        title: Row(
          children: [
            Text(l10n.appTitle),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
                _zipOutputs ? Icons.folder_zip : Icons.folder_zip_outlined),
            onPressed: () {
              setState(() {
                _zipOutputs = !_zipOutputs;
              });
              _savePreference('zipOutputs', _zipOutputs);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      _zipOutputs ? l10n.zipEnabledHint : l10n.zipDisabledHint),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: l10n.zipAllFiles,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: _showFileAnalyzer,
            tooltip: l10n.analyzeFile,
          ),
          IconButton(
            icon: const Icon(Icons.password_outlined),
            onPressed: _showSteganographyOptions,
            tooltip: l10n.steganographyTitle,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            onPressed: _showQrWatermarkOptions,
            tooltip: l10n.qrWatermarkTitle,
          ),
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
                      child: Column(
                        children: [
                          Expanded(
                              child: SingleChildScrollView(child: controls)),
                          const SizedBox(height: 16),
                          _buildAuthorFooter(theme),
                        ],
                      ),
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
                ? (screenHeight * 0.5).clamp(
                    350.0, 500.0) // 50% of screen height, min 350px, max 500px
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
        Row(
          children: [
            Expanded(
              child: Text(
                _statusMessage,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (_processing) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 14,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 4),
                    Text(
                      _elapsedTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (_processedFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          // Only show "Ready to save" message on desktop platforms where Save button is visible
          // if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) ...[
          //   Text(
          //     l10n.readyToSaveFiles(_processedFiles.length),
          //     style: theme.textTheme.bodySmall,
          //   ),
          // ],
          // Only show save location info on desktop platforms where Save button is visible
          if (!kIsWeb &&
              (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3)),
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

  Future<void> _saveLogs() async {
    if (_logs.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final timestamp =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
    final suggestedName = "securemark_logs_$timestamp.txt";

    try {
      final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName: suggestedName,
      );

      if (saveLocation == null) return;

      final logContent = _logs.join('\n');
      final logFile = XFile.fromData(
        Uint8List.fromList(utf8.encode(logContent)),
        name: suggestedName,
        mimeType: 'text/plain',
      );

      await logFile.saveTo(saveLocation.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.logsSaved(p.basename(saveLocation.path))),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _addLog('Error saving logs: $e');
    }
  }

  void _showLogs() {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.appLogs),
              if (_logs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: l10n.saveLogs,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _saveLogs();
                  },
                ),
            ],
          ),
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

  void _showAboutDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final l10n = AppLocalizations.of(context)!;
          return AlertDialog(
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'web/icons/Icon-192.png',
                    width: 48,
                    height: 48,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.security, size: 48),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.appTitle, style: theme.textTheme.titleLarge),
                      Text('v$_appVersion', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  l10n.appDescription,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(l10n.authorLabel('Antoine Giniès'),
                    style: theme.textTheme.bodyMedium),
                if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) ...[
                  // Only show on desktop
                  const SizedBox(height: 16), // Use this instead of 24
                  ElevatedButton.icon(
                    onPressed: _isCheckingForUpdates
                        ? null
                        : () => _checkForUpdates(setDialogState),
                    icon: _isCheckingForUpdates
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.system_update_alt),
                    label: Text(l10n.checkForUpdates),
                  ),
                  if (_updateMessage != null) ...[
                    // Display message only if present
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _updateMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                      Uri.parse('https://github.com/aginies/SecureMark')),
                  icon: const Icon(Icons.code),
                  label: Text(l10n.githubRepository),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(
                      'https://github.com/aginies/SecureMark/blob/master/PRIVACY_POLICY.md')),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: Text(l10n.privacyPolicy),
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
      ),
    );
  }

  bool _isCheckingForUpdates = false;
  String? _updateMessage;

  Future<void> _checkForUpdates(StateSetter setDialogState) async {
    final l10n = AppLocalizations.of(context)!;
    if (_isCheckingForUpdates) return;

    setDialogState(() {
      _isCheckingForUpdates = true;
      _updateMessage = l10n.checkingForUpdates;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://api.github.com/repos/aginies/SecureMark/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestTag = data['tag_name'] as String; // e.g. "v1.1.3"

        // Remove 'v' prefix if present for parsing
        final latestVersionStr =
            latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;

        final latestVersion = Version.parse(latestVersionStr);
        final currentVersion = Version.parse(_appVersion);

        if (latestVersion > currentVersion) {
          setDialogState(() {
            _updateMessage = l10n.updateAvailable(latestTag);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.updateAvailable(latestTag)),
                action: SnackBarAction(
                  label: l10n.viewUpdate,
                  onPressed: () => launchUrl(Uri.parse(
                      'https://github.com/aginies/SecureMark/releases/latest')),
                ),
              ),
            );
          }
        } else {
          setDialogState(() {
            _updateMessage = l10n.upToDate;
          });
        }
      } else {
        setDialogState(() {
          _updateMessage = l10n.updateCheckError;
        });
      }
    } catch (e) {
      setDialogState(() {
        _updateMessage = l10n.updateCheckError;
      });
    } finally {
      setDialogState(() {
        _isCheckingForUpdates = false;
      });
    }
  }

  void _showFileAnalyzer() {
    final l10n = AppLocalizations.of(context)!;

    // Clear extraction password when opening analyzer to ensure manual entry
    setState(() {
      _extractionPassword = '';
      _extractionPasswordController.text = '';
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.search_rounded),
                const SizedBox(width: 12),
                Text(l10n.fileAnalyzerTitle),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.steganographyPasswordLabel,
                    hintText: l10n.steganographyPasswordHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      _extractionPassword = value;
                    });
                    setState(() {
                      _extractionPassword = value;
                    });
                  },
                  controller: _extractionPasswordController,
                ),
                const SizedBox(height: 16),
                Text(l10n.fileAnalyzerDescription),
                const SizedBox(height: 24),
                if (_analyzingFile)
                  const CircularProgressIndicator()
                else if (_analysisResult != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.secondary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.analysisResult,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            if (_extractedFile == null &&
                                _analysisResult != null &&
                                !_analysisResult!
                                    .contains(l10n.noSignatureFound))
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Copy signature',
                                onPressed: () {
                                  // Extract the actual signature text from the result message
                                  // The result message is usually l10n.signatureFound(result)
                                  // For simplicity, let's just copy the whole thing or try to find the part after the colon
                                  final textToCopy =
                                      _analysisResult!.contains(': ')
                                          ? _analysisResult!
                                              .split(': ')
                                              .sublist(1)
                                              .join(': ')
                                          : _analysisResult!;
                                  Clipboard.setData(
                                      ClipboardData(text: textToCopy));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(l10n.signatureCopied),
                                        duration: const Duration(seconds: 2)),
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_analysisResult!),
                        if (_extractedFile != null &&
                            (!_extractedFile!.isEncrypted ||
                                _extractedFile!.fileBytes.isNotEmpty)) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _saveExtractedFile(),
                            icon: const Icon(Icons.save_alt),
                            label: Text(l10n.saveHiddenFile),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 48, color: Colors.grey),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _analyzingFile
                      ? null
                      : () => _pickAndAnalyze(setDialogState),
                  icon: const Icon(Icons.file_open),
                  label: Text(l10n.pickAndAnalyze),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _analysisResult = null;
                  _extractedFile = null;
                  Navigator.of(context).pop();
                },
                child: Text(l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _analyzingFile = false;
  String? _analysisResult;
  ExtractedFileResult? _extractedFile;

  Future<void> _pickAndAnalyze(StateSetter setDialogState) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'heic', 'heif'],
      withData: true, // Crucial for cloud providers
    );

    if (result == null || result.files.isEmpty) return;
    final pickedFile = result.files.single;

    setDialogState(() {
      _analyzingFile = true;
      _analysisResult = null;
      _extractedFile = null;
    });

    try {
      final bytes =
          pickedFile.bytes ?? await File(pickedFile.path!).readAsBytes();
      final password =
          _extractionPassword.isNotEmpty ? _extractionPassword : null;

      // Check for all types of hidden data in a single pass
      final analysis = await WatermarkProcessor.analyzeFileAsync(
          bytes, pickedFile.name,
          password: password);

      // Build combined result
      final results = <String>[];

      if (analysis.file != null) {
        final fileResult = analysis.file!;
        if (fileResult.isEncrypted && fileResult.fileBytes.isEmpty) {
          results.add(
              '🔐 Encrypted file detected: ${fileResult.fileName}. Please provide the correct password.');
        } else {
          _extractedFile = fileResult;
          results.add(
              '📁 Hidden file detected: ${fileResult.fileName} (${_formatFileSize(fileResult.fileBytes.length)})');
        }
      }

      if (analysis.signature != null && analysis.signature!.isNotEmpty) {
        final textResult = analysis.signature!;
        if (textResult.contains('[ENCRYPTED]')) {
          results.add(
              '🔐 Encrypted signature detected. Please provide the correct password.');
        } else {
          results.add(l10n.signatureFound(textResult));
        }
      }

      if (analysis.robustSignature != null &&
          analysis.robustSignature!.isNotEmpty) {
        results.add(l10n.robustSignatureFound(analysis.robustSignature!));
      }

      setDialogState(() {
        if (results.isEmpty) {
          _analysisResult = l10n.noSignatureFound;
        } else {
          _analysisResult = results.join('\n\n');
        }
      });
    } catch (e) {
      setDialogState(() {
        _analysisResult = l10n.analysisError(e.toString());
      });
    } finally {
      setDialogState(() {
        _analyzingFile = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _saveExtractedFile() async {
    final l10n = AppLocalizations.of(context)!;
    if (_extractedFile == null) return;

    // Safety check: don't save if it's encrypted and we don't have the decrypted bytes
    if (_extractedFile!.isEncrypted && _extractedFile!.fileBytes.isEmpty) {
      _addLog('Cannot save: file is encrypted and no password provided');
      return;
    }

    try {
      final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName: _extractedFile!.fileName,
      );

      if (saveLocation == null) {
        _addLog('Save cancelled by user');
        return;
      }

      final outputFile = XFile.fromData(
        _extractedFile!.fileBytes,
        name: _extractedFile!.fileName,
      );

      await outputFile.saveTo(saveLocation.path);

      _addLog('Extracted file saved to: ${saveLocation.path}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.fileSaved(p.basename(saveLocation.path))),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _addLog('Error saving extracted file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSavingFile(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showSteganographyOptions() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.steganographyTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    title: Text(l10n.steganographyTitle),
                    subtitle: Text(l10n.steganographySubtitle),
                    value: _useSteganography,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      final bool enabled = value ?? false;
                      setDialogState(() {
                        _useSteganography = enabled;
                      });
                      setState(() {
                        _useSteganography = enabled;
                      });
                      _savePreference('useSteganography', enabled);
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: Text(l10n.robustSteganographyTitle),
                    subtitle: Text(l10n.robustSteganographySubtitle),
                    value: _useRobustSteganography,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      final bool enabled = value ?? false;
                      setDialogState(() {
                        _useRobustSteganography = enabled;
                      });
                      setState(() {
                        _useRobustSteganography = enabled;
                      });
                      _savePreference('useRobustSteganography', enabled);
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: Text(l10n.hideFileWithSteganographyTitle),
                    subtitle: Text(l10n.hideFileWithSteganographySubtitle),
                    value: _hideFileWithSteganography,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      final enabled = value ?? false;
                      setDialogState(() {
                        _hideFileWithSteganography = enabled;
                        if (!enabled) {
                          // Clear hidden file if checkbox is unchecked
                          _hiddenFileBytes = null;
                          _hiddenFileName = null;
                          _savePreference('hiddenFileBytes', null);
                          _savePreference('hiddenFileName', null);
                        }
                      });
                      setState(() {
                        _hideFileWithSteganography = enabled;
                        if (!enabled) {
                          // Clear hidden file if checkbox is unchecked
                          _hiddenFileBytes = null;
                          _hiddenFileName = null;
                        }
                      });
                      _savePreference('hideFileWithSteganography', enabled);
                    },
                  ),
                  if (_hideFileWithSteganography) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.hiddenFileSecurityWarning,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          allowMultiple: false,
                          type: FileType.any,
                          withData: true, // Crucial for mobile cloud providers
                        );

                        if (result != null &&
                            result.files.single.bytes != null) {
                          final platformFile = result.files.single;
                          final fileBytes = platformFile.bytes!;
                          setDialogState(() {
                            _hiddenFileBytes = fileBytes;
                            _hiddenFileName = platformFile.name;
                          });
                          setState(() {
                            _hiddenFileBytes = fileBytes;
                            _hiddenFileName = platformFile.name;
                          });
                          _savePreference(
                              'hiddenFileBytes', base64Encode(fileBytes));
                          _savePreference('hiddenFileName', platformFile.name);
                        } else if (result != null &&
                            result.files.single.path != null) {
                          final platformFile = result.files.single;
                          final fileBytes =
                              await File(platformFile.path!).readAsBytes();
                          setDialogState(() {
                            _hiddenFileBytes = fileBytes;
                            _hiddenFileName = platformFile.name;
                          });
                          setState(() {
                            _hiddenFileBytes = fileBytes;
                            _hiddenFileName = platformFile.name;
                          });
                          _savePreference(
                              'hiddenFileBytes', base64Encode(fileBytes));
                          _savePreference('hiddenFileName', platformFile.name);
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _hiddenFileName != null && _hiddenFileName!.isNotEmpty
                            ? l10n.selectedHiddenFile(_hiddenFileName!)
                            : l10n.selectFileToHide,
                      ),
                    ),
                    if (_hiddenFileBytes != null &&
                        _hiddenFileBytes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _hidingPasswordController,
                        decoration: InputDecoration(
                          labelText: l10n.steganographyPasswordLabel,
                          hintText: l10n.steganographyPasswordHint,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        onChanged: (value) {
                          setState(() => _hidingPassword = value);
                          _savePreference('hidingPassword', value);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.steganographyPasswordNote,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic)),
                    ],
                  ],
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

  void _showQrWatermarkOptions() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.qr_code_2),
                  const SizedBox(width: 12),
                  Text(l10n.qrWatermarkTitle),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode selection
                    Text(l10n.qrMode, style: theme.textTheme.titleSmall),
                    CheckboxListTile(
                      title: Text(l10n.qrVisibleMode),
                      subtitle: Text(l10n.qrVisibleModeDesc),
                      value: _qrVisible,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(() => _qrVisible = value ?? false);
                        setState(() => _qrVisible = value ?? false);
                        _savePreference('qrVisible', value ?? false);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Content Type selection
                    Text(l10n.qrContentType, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<QrType>(
                          value: _qrType,
                          isExpanded: true,
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => _qrType = value);
                              setState(() => _qrType = value);
                              _savePreference('qrType', value.index);
                            }
                          },
                          items: [
                            DropdownMenuItem(
                                value: QrType.metadata,
                                child: Text(l10n.qrTypeMetadata)),
                            DropdownMenuItem(
                                value: QrType.url, child: Text(l10n.qrTypeUrl)),
                            DropdownMenuItem(
                                value: QrType.vcard,
                                child: Text(l10n.qrTypeVCard)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Content fields based on type
                    if (_qrType == QrType.metadata) ...[
                      TextField(
                        decoration: InputDecoration(
                          labelText: l10n.qrAuthorLabel,
                          hintText: l10n.qrAuthorHint,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() => _qrAuthor = value);
                          _savePreference('qrAuthor', value);
                        },
                        controller: _qrAuthorController,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: l10n.qrUrlLabel,
                          hintText: l10n.qrUrlHint,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() => _qrUrl = value);
                          _savePreference('qrUrl', value);
                        },
                        controller: _qrUrlController,
                      ),
                    ] else if (_qrType == QrType.url) ...[
                      TextField(
                        decoration: InputDecoration(
                          labelText: l10n.qrUrlLabel,
                          hintText: l10n.qrUrlHint,
                          border: const OutlineInputBorder(),
                          errorText: _qrUrl.isNotEmpty &&
                                  (Uri.tryParse(_qrUrl)?.hasScheme != true)
                              ? l10n.invalidUrlError
                              : null,
                        ),
                        keyboardType: TextInputType.url,
                        onChanged: (value) {
                          setDialogState(() => _qrUrl = value);
                          setState(() => _qrUrl = value);
                          _savePreference('qrUrl', value);
                        },
                        controller: _qrUrlController,
                      ),
                    ] else if (_qrType == QrType.vcard) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: l10n.vCardFirstName,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setState(() => _vCardFirstName = value);
                                _savePreference('vCardFirstName', value);
                              },
                              controller: _vCardFirstNameController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: l10n.vCardLastName,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setState(() => _vCardLastName = value);
                                _savePreference('vCardLastName', value);
                              },
                              controller: _vCardLastNameController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: l10n.vCardPhone,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        onChanged: (value) {
                          setState(() => _vCardPhone = value);
                          _savePreference('vCardPhone', value);
                        },
                        controller: _vCardPhoneController,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: l10n.vCardEmail,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (value) {
                          setState(() => _vCardEmail = value);
                          _savePreference('vCardEmail', value);
                        },
                        controller: _vCardEmailController,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: l10n.vCardOrg,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() => _vCardOrg = value);
                          _savePreference('vCardOrg', value);
                        },
                        controller: _vCardOrgController,
                      ),
                    ],

                    if (_qrVisible) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(l10n.qrVisibleOptions,
                          style: theme.textTheme.titleSmall),

                      // Position selector
                      const SizedBox(height: 8),
                      Text(l10n.qrPositionLabel),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<QrPosition>(
                            value: _qrPosition,
                            isExpanded: true,
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => _qrPosition = value);
                                setState(() => _qrPosition = value);
                                _savePreference('qrPosition', value.index);
                              }
                            },
                            items: [
                              DropdownMenuItem(
                                  value: QrPosition.topLeft,
                                  child: Text(l10n.qrPosTopLeft)),
                              DropdownMenuItem(
                                  value: QrPosition.topRight,
                                  child: Text(l10n.qrPosTopRight)),
                              DropdownMenuItem(
                                  value: QrPosition.bottomLeft,
                                  child: Text(l10n.qrPosBottomLeft)),
                              DropdownMenuItem(
                                  value: QrPosition.bottomRight,
                                  child: Text(l10n.qrPosBottomRight)),
                              DropdownMenuItem(
                                  value: QrPosition.center,
                                  child: Text(l10n.qrPosCenter)),
                            ],
                          ),
                        ),
                      ),

                      // Size slider
                      const SizedBox(height: 16),
                      Text(l10n.qrSizeValue(_qrSize.round()),
                          style: theme.textTheme.titleSmall),
                      Slider(
                        value: _qrSize,
                        min: 50,
                        max: 200,
                        divisions: 15,
                        onChanged: (value) {
                          setDialogState(() => _qrSize = value);
                          setState(() => _qrSize = value);
                          _savePreference('qrSize', value);
                        },
                      ),

                      // Opacity slider
                      Text(l10n.qrOpacityValue((_qrOpacity * 100).round()),
                          style: theme.textTheme.titleSmall),
                      Slider(
                        value: _qrOpacity,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        onChanged: (value) {
                          setDialogState(() => _qrOpacity = value);
                          setState(() => _qrOpacity = value);
                          _savePreference('qrOpacity', value);
                        },
                      ),
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
            );
          },
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
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        labelText: l10n.filePrefixLabel,
                        hintText: l10n.filePrefixHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filePrefix = value;
                        });
                        _savePreference('filePrefix', value);
                      },
                      controller: _filePrefixController,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.fontSizeValue(_fontSize.round()),
                        style: theme.textTheme.titleSmall),
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
                        _savePreference('fontSize', value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.fontStyleLabel),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
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
                              setDialogState(() {
                                _selectedFont = newFont;
                              });
                              setState(() {
                                _selectedFont = newFont;
                              });
                              _savePreference(
                                  'selectedFont', newFont.fontFamily);
                            }
                          },
                          items: _buildFontDropdownItems(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getFontSourceDescription(context),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.jpegQualityValue(_jpegQuality),
                        style: theme.textTheme.titleSmall),
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
                        _savePreference('jpegQuality', value.round());
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
                        _savePreference('includeTimestamp', value ?? false);
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
                        _savePreference('preserveMetadata', value ?? false);
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
                        _savePreference('rasterizePdf', value ?? false);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.antiAiProtectionValue(_antiAiLevel.round()),
                        style: theme.textTheme.titleSmall),
                    Slider(
                      value: _antiAiLevel,
                      min: 0,
                      max: 100,
                      divisions: 10,
                      onChanged: (value) {
                        setDialogState(() {
                          _antiAiLevel = value;
                        });
                        setState(() {
                          _antiAiLevel = value;
                        });
                        _savePreference('antiAiLevel', value);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        l10n.antiAiProtectionNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.imageResizingLabel('').replaceAll(': ', ''),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _targetSize,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<int?>(
                                value: null, child: Text(l10n.resizeNone)),
                            DropdownMenuItem<int?>(
                                value: 2048, child: Text(l10n.pixelUnit(2048))),
                            DropdownMenuItem<int?>(
                                value: 1600, child: Text(l10n.pixelUnit(1600))),
                            DropdownMenuItem<int?>(
                                value: 1280, child: Text(l10n.pixelUnit(1280))),
                            DropdownMenuItem<int?>(
                                value: 1024, child: Text(l10n.pixelUnit(1024))),
                            DropdownMenuItem<int?>(
                                value: 800, child: Text(l10n.pixelUnit(800))),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              _targetSize = value;
                            });
                            setState(() {
                              _targetSize = value;
                            });
                            _savePreference('targetSize', value);
                          },
                        ),
                      ),
                    ),
                    if (!kIsWeb &&
                        (Platform.isLinux ||
                            Platform.isMacOS ||
                            Platform.isWindows)) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        l10n.outputDirectoryLabel(
                            _outputDirectory ?? l10n.resizeNone),
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
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();

                        setDialogState(() {
                          _fontSize = 24.0;
                          _jpegQuality = 75;
                          _targetSize = null;
                          _includeTimestamp = true;
                          _preserveMetadata = false;
                          _rasterizePdf = false;
                          _filePrefix = 'securemark-';
                          _antiAiLevel = 50.0;
                          _useRandomColor = true;
                          _selectedColor = Colors.deepPurple;
                          _selectedFont = WatermarkFont.arial;
                        });

                        setState(() {
                          _fontSize = 24.0;
                          _jpegQuality = 75;
                          _targetSize = null;
                          _includeTimestamp = true;
                          _preserveMetadata = false;
                          _rasterizePdf = false;
                          _filePrefix = 'securemark-';
                          _antiAiLevel = 50.0;
                          _useRandomColor = true;
                          _selectedColor = Colors.deepPurple;
                          _selectedFont = WatermarkFont.arial;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.resetToDefaults),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                  if (_selectedPaths.isNotEmpty) ...[
                    Text(
                      l10n.selectedFilesLabel(_selectedPaths.length),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _selectedPaths.length,
                        itemBuilder: (context, index) {
                          final fileName = p.basename(_selectedPaths[index]);
                          return ListTile(
                            leading: Icon(Icons.insert_drive_file_outlined,
                                color: theme.colorScheme.primary),
                            title: Text(fileName),
                            dense: true,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.clickApplyToPreview,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ] else if (_rawImage != null && _shaderProgram != null) ...[
                    // Live Shader Preview!
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: AspectRatio(
                        aspectRatio: _rawImage!.width / _rawImage!.height,
                        child: CustomPaint(
                          painter: WatermarkShaderPainter(
                            shader: _shaderProgram!.fragmentShader(),
                            image: _rawImage!,
                            color: _useRandomColor
                                ? Colors.deepPurple
                                : _selectedColor,
                            transparency: _transparency,
                          ),
                        ),
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
                      l10n.emptyPreviewHint,
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
                        final previewBytes =
                            _processedFiles[index].result.previewBytes;
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
                                final currentScale = _transformationController
                                    .value
                                    .getMaxScaleOnAxis();
                                // Smart zoom: cycle through 1.0 -> 2.0 -> 3.0 -> 1.0
                                final targetScale = currentScale <= 1.0
                                    ? 2.0
                                    : currentScale <= 2.0
                                        ? 3.0
                                        : 1.0;

                                if (!kIsWeb &&
                                    (Platform.isAndroid || Platform.isIOS)) {
                                  HapticFeedback.lightImpact();
                                }

                                _transformationController.value =
                                    Matrix4.diagonal3Values(
                                        targetScale, targetScale, 1.0);
                              },
                              child: InteractiveViewer(
                                transformationController:
                                    _transformationController,
                                minScale: 0.5,
                                maxScale: 4.0,
                                panEnabled: true,
                                scaleEnabled: true,
                                child: Center(
                                  child: Image.memory(
                                    _showOriginalPreview
                                        ? _processedFiles[index]
                                            .result
                                            .originalBytes! // Display original
                                        : previewBytes, // Display processed
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            // A/B button
                            if (_processedFiles[index].result.originalBytes !=
                                null)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: FloatingActionButton.small(
                                  heroTag: "ab_toggle_$index",
                                  onPressed: () {
                                    setState(() {
                                      _showOriginalPreview =
                                          !_showOriginalPreview;
                                    });
                                  },
                                  backgroundColor: theme.colorScheme.surface
                                      .withValues(alpha: 0.9),
                                  child: Icon(
                                    _showOriginalPreview
                                        ? Icons.flip_to_front
                                        : Icons.flip_to_back,
                                    size: 20,
                                  ),
                                ),
                              ),
                            // Steganography verification badge
                            if (_processedFiles[index]
                                    .result
                                    .steganographyVerified ||
                                _processedFiles[index].result.robustVerified)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_user_outlined,
                                          color: Colors.white, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Navigation arrows for Desktop
                            if (!kIsWeb &&
                                (Platform.isLinux ||
                                    Platform.isWindows ||
                                    Platform.isMacOS) &&
                                _processedFiles.length > 1) ...[
                              Positioned(
                                left: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: IconButton.filledTonal(
                                    onPressed: _previewIndex > 0
                                        ? () => _previewController.previousPage(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.easeInOut)
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
                                    onPressed: _previewIndex <
                                            _processedFiles.length - 1
                                        ? () => _previewController.nextPage(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.easeInOut)
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
                                if (scale <= 1.0) {
                                  return const SizedBox.shrink();
                                }

                                return Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: FloatingActionButton.small(
                                    heroTag:
                                        "zoom_reset_$index", // Unique hero tag for PageView
                                    onPressed: () {
                                      if (!kIsWeb &&
                                          (Platform.isAndroid ||
                                              Platform.isIOS)) {
                                        HapticFeedback.lightImpact();
                                      }
                                      _transformationController.value =
                                          Matrix4.identity();
                                    },
                                    backgroundColor: theme.colorScheme.surface
                                        .withValues(alpha: 0.9),
                                    child: const Icon(Icons.zoom_out_map,
                                        size: 20),
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

    return InkWell(
      onTap: _showAboutDialog,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
        ),
      ),
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
          backgroundColor: isDragging
              ? theme.colorScheme.primary.withValues(alpha: 0.8)
              : null,
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
                    ? l10n.selectedFile(
                        File(_selectedPaths.first).uri.pathSegments.last)
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
              onPressed: _processing || _selectedPaths.isEmpty
                  ? null
                  : _applyWatermark,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(l10n.applyWatermark),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
            // Status icons group
            if ((_useSteganography && !_steganographyVerificationFailed) ||
                _useRobustSteganography ||
                _steganographyVerificationFailed ||
                _qrVisible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_useSteganography && !_steganographyVerificationFailed)
                      Tooltip(
                        message: l10n.steganographyEnabledHint,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.0),
                          child: Icon(Icons.verified_user_outlined,
                              color: Colors.green),
                        ),
                      ),
                    if (_useRobustSteganography)
                      Tooltip(
                        message: l10n.robustSteganographyTitle,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.0),
                          child:
                              Icon(Icons.shield_outlined, color: Colors.indigo),
                        ),
                      ),
                    if (_steganographyVerificationFailed)
                      Tooltip(
                        message: l10n.steganographyVerificationFailed,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.0),
                          child: Icon(Icons.warning_outlined, color: Colors.red),
                        ),
                      ),
                    if (_qrVisible)
                      Tooltip(
                        message: l10n.qrWatermarkTitle,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.0),
                          child: Icon(Icons.qr_code_2, color: Colors.blue),
                        ),
                      ),
                  ],
                ),
              ),
            // Hide Save button on mobile platforms (iOS/Android)
            if (!isMobile)
              FilledButton.icon(
                onPressed: _processing || _processedFiles.isEmpty
                    ? null
                    : _saveCurrent,
                icon: const Icon(Icons.save_alt),
                label: Text(l10n.saveAll),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                ),
              ),
            FilledButton.icon(
              onPressed:
                  _processing || _processedFiles.isEmpty ? null : _shareCurrent,
              icon: const Icon(Icons.share_outlined),
              label: Text(l10n.shareAll),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _processing ? null : _reset,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reset),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                    ButtonSegment<bool>(
                        value: true, label: Text(l10n.randomColor)),
                    ButtonSegment<bool>(
                        value: false, label: Text(l10n.selectedColor)),
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
                      final isSelected =
                          color.toARGB32() == _selectedColor.toARGB32();
                      return InkWell(
                        onTap: _processing ? null : () => _selectColor(color),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey.shade400,
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
          min: 0,
          max: 100,
          divisions: 80,
          onChanged: _processing
              ? null
              : (value) {
                  setState(() {
                    _transparency = value;
                  });
                  _savePreference('transparency', value);
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
                  _savePreference('density', value);
                },
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'pdf',
          'heic',
          'heif'
        ],
        withData: false, // We usually want paths for main files
        lockParentWindow: true,
      );

      if (result == null || result.files.isEmpty) {
        _addLog('File picker cancelled or no files selected.');
        return;
      }

      _addLog('Picked ${result.files.length} files via picker.');

      final validPaths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();

      if (validPaths.isNotEmpty) {
        _selectPaths(validPaths);
      } else {
        _addLog('Error: Picked files have no valid local paths.');
      }
    } catch (e) {
      _addLog('Error picking files: $e');
    }
  }

  void _selectPaths(List<String> paths) {
    final uniquePaths = paths.toSet().toList();

    setState(() {
      _selectedPaths = uniquePaths;
      _processedFiles = <_ProcessedFile>[];
      _previewIndex = 0;
      _rawImage = null; // Clear old image
      _statusMessage = ''; // Removed "Selected X files..." message
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
        }).catchError((e) {
          _addLog('Error reading first image for preview: $e');
          debugPrint('Preview error: $e');
        });
      }
    }
  }

  Future<void> _processPaths(List<String> paths) async {
    if (_processing || paths.isEmpty) return;

    // Clear cache to force regeneration
    WatermarkProcessor.clearCache();

    _addLog('Processing ${paths.length} paths');
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    _cancellationToken = CancellationToken();
    _startStopwatch();

    setState(() {
      _processing = true;
      _processedFiles = <_ProcessedFile>[];
      _previewIndex = 0;
      _progress = 0.0;
      _progressMessage = '';
      _elapsedTime = '00:00';
      _statusMessage = l10n.processingCount(paths.length);
    });

    await _cleanupTempFiles();

    if (!mounted) return;

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
                ? (_statusMessage.isEmpty
                    ? l10n.processingFile
                    : _statusMessage)
                : _progressMessage;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          value: _progress > 0 ? _progress : null,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Text(
                        _elapsedTime,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.applyingWatermark,
                      style: theme.textTheme.titleMedium),
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
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).round()}${['fr', 'de'].contains(Localizations.localeOf(context).languageCode) ? ' %' : '%'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
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
          _statusMessage =
              l10n.processingNamedFile(i + 1, paths.length, fileName);
        });
        _progressListener?.call();

        // Build QR config if enabled
        QrWatermarkConfig? qrConfig;
        if (_qrVisible) {
          qrConfig = QrWatermarkConfig(
            type: _qrType,
            author: _qrAuthor.isNotEmpty ? _qrAuthor : null,
            url: _qrUrl.isNotEmpty ? _qrUrl : null,
            vCardFirstName: _vCardFirstName.isNotEmpty ? _vCardFirstName : null,
            vCardLastName: _vCardLastName.isNotEmpty ? _vCardLastName : null,
            vCardPhone: _vCardPhone.isNotEmpty ? _vCardPhone : null,
            vCardEmail: _vCardEmail.isNotEmpty ? _vCardEmail : null,
            vCardOrg: _vCardOrg.isNotEmpty ? _vCardOrg : null,
            timestamp: DateTime.now(),
            position: _qrPosition,
            size: _qrSize,
            opacity: _qrOpacity,
            visibleQr: _qrVisible,
          );
        }

        // Apply steganography if either signature or file hiding is enabled
        final bool shouldApplyStegano = _useSteganography ||
            (_hideFileWithSteganography && _hiddenFileBytes != null);

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
            filePrefix: _filePrefix,
            antiAiLevel: _antiAiLevel,
            useSteganography: shouldApplyStegano,
            useRobustSteganography: _useRobustSteganography,
            steganographyPassword: _hidingPassword,
            hiddenFileName: _hideFileWithSteganography ? _hiddenFileName : null,
            hiddenFileBytes:
                _hideFileWithSteganography ? _hiddenFileBytes : null,
            qrConfig: qrConfig,
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
              _statusMessage = e is WatermarkError
                  ? e.userMessage
                  : l10n.errorPrefix(e.toString());
            });
            _progressListener?.call();
          }
        }
      }
    } finally {
      _stopStopwatch();
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
          // Log steganography verification results
          final verifiedCount = processedFiles
              .where((f) =>
                  f.result.steganographyVerified || f.result.robustVerified)
              .length;
          final steganographyFailed =
              (_useSteganography || _useRobustSteganography) &&
                  processedFiles.isNotEmpty &&
                  verifiedCount == 0;

          if ((_useSteganography || _useRobustSteganography) &&
              verifiedCount > 0) {
            _addLog('Steganography verified for $verifiedCount file(s)');
          } else if (_useSteganography || _useRobustSteganography) {
            _addLog('Steganography verification failed for all files');
          }

          var successMessage = processedFiles.isEmpty
              ? l10n.processingFailed
              : failedFiles.isEmpty
                  ? '' // No message if files are processed and no failures
                  : l10n.processingStatusMultiple(
                      processedFiles.length, failedFiles.length);

          if ((_useSteganography || _useRobustSteganography) &&
              verifiedCount > 0) {
            successMessage += ' (Steganography Verified ✓)';
          }

          setState(() {
            _processedFiles = processedFiles;
            _previewIndex = 0;
            _statusMessage = successMessage;
            _processing = false;
            _progress = 1.0;
            _steganographyVerificationFailed = steganographyFailed;
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
    _stopStopwatch();
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

  void _startStopwatch() {
    _stopwatch?.stop();
    _timer?.cancel();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_stopwatch == null || !_stopwatch!.isRunning) {
        timer.cancel();
        return;
      }
      final duration = _stopwatch!.elapsed;
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      if (mounted) {
        setState(() {
          _elapsedTime = '$minutes:$seconds';
        });
        _progressListener?.call();
      }
    });
  }

  void _stopStopwatch() {
    _stopwatch?.stop();
    _timer?.cancel();
  }

  Future<void> _reset() async {
    _cancellationToken?.cancel();
    _stopStopwatch();
    _textController.clear();

    // Clear all preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      _addLog('Error clearing preferences: $e');
    }

    // Clear processor cache and cleanup temp files
    WatermarkProcessor.clearCache();
    await _cleanupTempFiles();

    if (_previewController.hasClients) {
      _previewController.jumpToPage(0);
    }
    setState(() {
      _dragging = false;
      _processing = false;
      _progress = 0.0;
      _progressMessage = '';
      _elapsedTime = '00:00';
      _transparency = 75;
      _density = 35;
      _selectedPaths = <String>[];
      _processedFiles = <_ProcessedFile>[];
      _previewIndex = 0;
      _statusMessage = '';
      _cancellationToken = null;
      _rawImage = null;

      // Reset expert settings
      _fontSize = 24.0;
      _jpegQuality = 75;
      _targetSize = null;
      _includeTimestamp = true;
      _preserveMetadata = false;
      _rasterizePdf = false;
      _filePrefix = 'securemark-';
      _antiAiLevel = 50.0;
      _useSteganography = false;
      _hideFileWithSteganography = false;
      _hiddenFileBytes = null;
      _hiddenFileName = null;
      _hidingPassword = '';
      _extractionPassword = '';
      _useRandomColor = true;
      _selectedColor = Colors.deepPurple;
      _selectedFont = WatermarkFont.arial;
      _steganographyVerificationFailed = false;
    });
  }

  Future<void> _applyWatermark() async {
    if (_selectedPaths.isEmpty) {
      return;
    }

    // Reset preview state before starting new processing
    setState(() {
      _processedFiles = <_ProcessedFile>[];
      _previewIndex = 0;
      _showOriginalPreview = false;
      _transformationController.value = Matrix4.identity();
      _steganographyVerificationFailed = false;
    });

    // Reset preview controller to first page if it has clients
    if (_previewController.hasClients) {
      _previewController.jumpToPage(0);
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
        statusMessage =
            l10n.saveStatusMultiple(savedFiles.length, failedFiles.length);
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
    final displayDir =
        _outputDirectory != null ? _outputDirectory! : p.basename(directory);

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
  void _showSaveResultDialog(
      List<String> savedFiles, List<String> failedFiles) {
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
    final sharePositionOrigin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    if (_processedFiles.isEmpty) {
      return;
    }

    final shareFiles = <XFile>[];

    if (_zipOutputs) {
      // Create ZIP archive
      final encoder = ZipEncoder();
      final archive = Archive();

      for (final file in _processedFiles) {
        final fileName = p.basename(file.result.outputPath);
        final archiveFile = ArchiveFile(
          fileName,
          file.result.outputBytes.length,
          file.result.outputBytes,
        );
        archive.addFile(archiveFile);
      }

      final zipData = encoder.encode(archive);
      if (zipData != null) {
        final tempDir = await getTemporaryDirectory();
        final zipPath = p.join(tempDir.path, 'securemark-files.zip');
        await File(zipPath).writeAsBytes(zipData);
        _tempFiles.add(zipPath);
        shareFiles.add(XFile(zipPath, mimeType: 'application/zip'));
      }
    } else {
      // Share individual files
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
    _savePreference('useRandomColor', useRandomColor);
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
    });
    _savePreference('selectedColor', color.toARGB32());
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
