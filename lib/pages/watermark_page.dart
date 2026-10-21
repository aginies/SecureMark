import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';

import '../l10n/app_localizations.dart';
import '../watermark_processor.dart';
import '../font_manager.dart';
import '../qr_config.dart';
import '../models/processed_file.dart';
import '../models/settings_profile.dart';
import '../models/identity_bookmark.dart';
import '../widgets/color_tile.dart';
import '../widgets/comparison_clipper.dart';
import '../widgets/density_painter.dart';
import '../widgets/gradient_button.dart';
import '../widgets/profile_tile.dart';
import '../widgets/xy_pad_painter.dart';
import '../widgets/watermark_shader_painter.dart';
import '../main.dart';
import '../watermark_error.dart';
import '../models/processor_models.dart';
import '../utils/browser_download.dart';
import '../utils/color_utils.dart';
import '../utils/identity_manager.dart';
import '../utils/local_server_manager.dart';
import '../utils/web_file_store.dart';
import '../utils/certificate_manager.dart';
import '../utils/watermark_utils.dart';
import '../steganography/encryption_utils.dart';
import '../steganography/forensic_utils.dart';
import '../models/watermark_option.dart';
import '../widgets/option_toggle_grid.dart';
import 'onboarding_page.dart';

part 'parts/state.builders.dart';
part 'parts/state.config_backup.dart';
part 'parts/state.file_picking.dart';
part 'parts/state.forensics.dart';
part 'parts/state.local_share.dart';
part 'parts/state.misc_dialogs.dart';
part 'parts/state.preferences.dart';
part 'parts/state.processing.dart';
part 'parts/state.steganography.dialogs.dart';
part 'parts/state.watermark_editing.dart';
part 'parts/state.web.dart';

/// Whether [key] is part of the SecureMark configuration backup.
///
/// Shared by the export and import paths so an imported
/// `securemark_config.json` can only write keys the export path would
/// produce. Anything else (e.g. `https_cert_fingerprint`) is rejected,
/// preventing a malicious backup zip from injecting arbitrary
/// SharedPreferences state.
bool _isConfigBackupKey(String key) {
  // The Ed25519 identity key pair belongs strictly to this device: neither the
  // private key nor the public key can ever be part of a backup export or import.
  // Excluding device_public_key prevents public key poisoning (mismatched keypair
  // that breaks digital signature verification).
  if (key == 'device_private_key' || key == 'device_public_key') return false;
  if (key.startsWith('device_')) return false;
  if (key.startsWith('profile_')) return true;
  return const {
    'transparency',
    'density',
    'fontSize',
    'jpegQuality',
    'targetSize',
    'includeTimestamp',
    'preserveMetadata',
    'rasterizePdf',
    'antiAiLevel',
    'useSteganography',
    'useRobustSteganography',
    'useAiCloaking',
    'digitallySign',
    'deviceName',
    'filePrefix',
    'selectedProfile',
    'selectedFont',
    'qrVisible',
    'qrType',
    'qrAuthor',
    'qrUrl',
    'identity_bookmarks',
  }.contains(key);
}

/// Preference keys that must be stored as ints, because they are read back
/// with [SharedPreferences.getInt]. Profile-scoped keys reuse the same
/// suffixes (e.g. `profile_watermark_jpegQuality`), so match on suffixes.
const Set<String> _intPreferenceKeySuffixes = {
  'jpegQuality',
  'targetSize',
  'selectedColor',
  'selectedProfile',
  'qrType',
  'qrPosition',
  'watermarkType',
};

/// Whether [key] is persisted as an int rather than a double.
///
/// On Web every number is a double, so `value is int` / `value is double`
/// cannot reliably pick the right typed setter. The expected type of each
/// preference key is fixed, so dispatch on the key instead.
bool _isIntPreferenceKey(String key) =>
    _intPreferenceKeySuffixes.any((suffix) => key.endsWith(suffix));

class WatermarkPage extends StatefulWidget {
  final bool hasCamera;
  const WatermarkPage({super.key, this.hasCamera = true});

  @override
  State<WatermarkPage> createState() => WatermarkPageState();
}

class WatermarkPageState extends State<WatermarkPage>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();

  final TextEditingController _steganographyTextController =
      TextEditingController();

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

  final TextEditingController _deviceNameController = TextEditingController();

  final TextEditingController _pdfUserPasswordController =
      TextEditingController();

  final TextEditingController _pdfOwnerPasswordController =
      TextEditingController();

  final TextEditingController _secureZipPasswordController =
      TextEditingController();

  final TextEditingController _filePrefixController = TextEditingController();

  final TransformationController _transformationController =
      TransformationController();

  final PageController _previewController = PageController();

  final ScrollController _profileScrollController = ScrollController();

  double _transparency = 75;

  double _density = 35;

  double _fontSize = 24;

  double _logoSize = 100;

  WatermarkFont _selectedFont = FontManager.getDefaultFont();

  int _jpegQuality = 75;

  int? _targetSize = 1280;

  bool _forcePng = false;

  bool _includeTimestamp = true;

  bool _preserveMetadata = false;

  bool _rasterizePdf = false;

  bool _enablePdfSecurity = false;

  bool _pdfAllowPrinting = false;

  bool _pdfAllowCopying = false;

  bool _pdfAllowEditing = false;

  String _filePrefix = 'securemark-';

  double _antiAiLevel = 50.0;

  bool _useSteganography = false;

  bool _useRobustSteganography = false;

  bool _useAiCloaking = false;

  bool _digitallySign = false;

  bool _steganographyVerificationFailed = false;

  bool _useRandomColor = true;

  Color _selectedColor = Colors.red;

  SettingsProfile _selectedProfile = SettingsProfile.none;

  bool _dragging = false;

  bool _logoDragging = false;

  bool _loadingFiles = false;

  bool _processing = false;

  bool _hasErrors = false;

  double _progress = 0.0;

  bool _obscureHidingPassword = true;

  bool _obscureSecureZipPassword = true;

  bool _obscureExtractionPassword = true;

  String _statusMessage = '';

  String _modalProgressStatus = '';

  String _progressMessage = '';

  String _elapsedTime = '00:00';

  String _appVersion = '';

  String? _outputDirectory;

  String? _logoDirectory;

  List<IdentityBookmark> _identityBookmarks = [];

  /// Last file received over the local network, kept so the auto-verify
  /// badge can re-open the full analysis on demand.
  Uint8List? _receivedFileBytes;

  String? _receivedFileName;

  ui.Image? _rawImage;

  final List<String> _logs = <String>[];

  final List<String> _tempFiles = <String>[];

  List<String> _selectedPaths = <String>[];

  Timer? _webRetentionTimer;

  DateTime? _webRetentionDeadline;

  ui.FragmentProgram? _shaderProgram;

  Stopwatch? _stopwatch;

  Timer? _timer;

  PreviewMode _previewMode = PreviewMode.processed;

  double _comparisonSliderValue = 0.5;

  bool _hideFileWithSteganography = false;

  Uint8List? _hiddenFileBytes;

  String? _hiddenFileName;

  String _hidingPassword = '';

  String _extractionPassword = '';

  String _deviceName = '';

  String? _devicePublicKey;

  bool _zipOutputs = false;

  bool _useSecureZip = false;

  WatermarkType _watermarkType = WatermarkType.text;

  Uint8List? _watermarkImageBytes;

  String? _watermarkImageName;

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

  // Local Share State

  List<NetworkInterfaceInfo> _networkInterfaces = [];

  int _servingPort = 0;

  String? _sendingFileName;

  int _selectedInterfaceIndex = 0;

  int _transferProgress = 0;

  int _transferTotal = 0;

  String? _localEncryptionKey;

  bool _useLocalEncryption = true;

  bool _pushToReceiver = false;

  bool _useHttps = false;

  String? _certificateFingerprint;

  bool _showReceiveQr = false;

  bool _hasPromptedForMobileDir = false;

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
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    }
  }

  List<ProcessedFile> _processedFiles = <ProcessedFile>[];

  int _previewIndex = 0;

  CancellationToken? _cancellationToken;

  Timer? _shareCheckTimer1;

  Timer? _shareCheckTimer2;

  /// Forwards to [State.setState] so that part-file extension members can
  /// refresh the UI without accessing the protected [State.setState] member.
  void _refresh(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _profileScrollController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);
    _setupPlatformCallHandler();
    _loadPreferences();
    _loadBookmarks();
    _loadShader();
    _initPackageInfo();
    IdentityManager.onLog = _addLog;
    // A processed document's embedded signature belongs to whichever identity
    // was active when it was produced, so results cached under the old key are
    // invalid the moment the identity changes.
    IdentityManager.onIdentityChanged = WatermarkProcessor.clearCache;
    // The web UI does not sign: don't auto-generate an identity key pair
    // and persist the private key to localStorage for every visitor.
    // (Opening the identity dialog explicitly still creates one on demand.)
    if (!kIsWeb) {
      IdentityManager.getIdentityKeyPair().then((_) async {
        final pk = await IdentityManager.getDevicePublicKey();
        if (mounted) setState(() => _devicePublicKey = pk);
      });
    }

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
  @override
  void dispose() {
    _cleanupTempFiles();
    _shareCheckTimer1?.cancel();
    _shareCheckTimer2?.cancel();
    _webRetentionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _steganographyTextController.dispose();
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
    _profileScrollController.dispose();
    super.dispose();
  }

  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check for shared content when app comes back to foreground
      _handleSharedContent();
    }
  }

  bool get _supportsDesktopDrop =>
      !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  /// Guards for the apply action: nothing to run while a job is in flight,
  /// before a file is picked, or when the image watermark has no logo loaded.
  bool get _canApplyWatermark =>
      !_processing &&
      _selectedPaths.isNotEmpty &&
      !(_watermarkType == WatermarkType.image && _watermarkImageBytes == null);

  ProcessedFile? get _currentProcessedFile {
    if (_processedFiles.isEmpty) {
      return null;
    }
    final safeIndex = _previewIndex.clamp(0, _processedFiles.length - 1);
    return _processedFiles[safeIndex];
  }

  @override
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // The "magic wand" stays pinned top-left: one click to run
            // SecureMark on the current selection, whatever the screen size.
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              onPressed: _canApplyWatermark ? _applyWatermark : null,
              tooltip: l10n.applyWatermark,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            // Secondary tools live in a labeled overflow menu: the old
            // row of icon-only buttons overflowed narrow app bars and was
            // the main source of "where is that feature?" confusion.
            PopupMenuButton<String>(
              tooltip: l10n.moreOptions,
              onSelected: (value) {
                switch (value) {
                  case 'analyze':
                    _showFileAnalyzer();
                  case 'steganography':
                    _showSteganographyOptions();
                  case 'identity':
                    _showIdentityDialog();
                  case 'localShare':
                    _showLocalShareDialog();
                  case 'qr':
                    _showQrWatermarkOptions();
                  case 'font':
                    _showFontOptions();
                  case 'expertOptions':
                    _showExpertOptions();
                }
              },
              itemBuilder: (context) => [
                _toolMenuItem(
                    'font', Icons.image_outlined, l10n.fontConfigTitle),
                _toolMenuItem('qr', Icons.qr_code_2, l10n.qrWatermarkTitle),
                // Local share and the file analyzer are not part of the web
                // UI: on web the output is a browser download (see
                // _shareCurrent) and there is no LAN socket. Device identity
                // and steganography run fully on-device (WASM isolate), so
                // they are available on web.
                _toolMenuItem('identity', Icons.person_pin_outlined,
                    l10n.myIdentityTitle),
                if (!kIsWeb)
                  _toolMenuItem(
                      'localShare', Icons.sensors, l10n.localShareTitle),
                _toolMenuItem('steganography', Icons.verified_user_outlined,
                    l10n.steganographyTitle),
                if (!kIsWeb)
                  _toolMenuItem(
                      'analyze', Icons.search_rounded, l10n.analyzeFile),
                // Expert Options (file naming, PDF and security settings) sits
                // last: it is the least-used panel, so it no longer claims a
                // permanent spot in the bar.
                _toolMenuItem('expertOptions', Icons.settings_suggest_outlined,
                    l10n.expertOptions),
              ],
            ),
            // The zero-server promise belongs in the app bar of the web build:
            // a document tool served over the network has to say "nothing is
            // uploaded" before the user picks a file, not in a footer below
            // the fold. Tap opens « Confidentialité ».
            if (kIsWeb) ...[
              const SizedBox(width: 4),
              Expanded(child: _buildWebPrivacyBadge(theme, l10n)),
            ],
          ],
        ),
        centerTitle: false,
      ),
      // Apply is the one primary action of the page: it floats over the
      // preview panel at bottom-right, where the eye lands after picking a
      // file, and stays reachable while the controls column scrolls.
      floatingActionButton: _buildApplyFloatingButton(l10n, theme),
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

  /// Labeled overflow-menu entry: fixed icon, ellipsized text so long
  /// localized labels (e.g. FR steganography) cannot overflow the menu.
  PopupMenuItem<String> _toolMenuItem(
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  bool _isCheckingForUpdates = false;

  String? _updateMessage;

  bool _analyzingFile = false;

  String? _analysisResult;

  String? _extractedSignature;

  VerificationResult? _verificationResult;

  bool _integrityVerified = false;

  String? _senderPublicKey;

  ExtractedFileResult? _extractedFile;

  BatchAnalysisResult? _batchAnalysisResult;

  int? _selectedFileIndex;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  VoidCallback? _progressListener;
}
