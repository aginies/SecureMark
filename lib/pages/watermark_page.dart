import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

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
import '../widgets/watermark_shader_painter.dart';
import '../widgets/profile_chip.dart';
import '../main.dart';
import '../watermark_error.dart';
import '../models/processor_models.dart';
import '../utils/identity_manager.dart';
import '../utils/local_server_manager.dart';
import '../steganography/encryption_utils.dart';
import '../models/watermark_option.dart';
import '../widgets/option_toggle_grid.dart';
import 'onboarding_page.dart';

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
  double _progress = 0.0;
  bool _obscureHidingPassword = true;
  bool _obscureSecureZipPassword = true;
  bool _obscureExtractionPassword = true;
  String _statusMessage = '';
  String _progressMessage = '';
  String _elapsedTime = '00:00';
  String _appVersion = '';
  String? _outputDirectory;
  String? _logoDirectory;
  List<IdentityBookmark> _identityBookmarks = [];
  ui.Image? _rawImage;
  final List<String> _logs = <String>[];
  final List<String> _tempFiles = <String>[];
  List<String> _selectedPaths = <String>[];
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
  List<String> _localIps = [];
  int _servingPort = 0;
  String? _sendingFileName;
  int _selectedLocalIpIndex = 0;
  String? _localEncryptionKey;
  bool _useLocalEncryption = true;
  bool _showReceiveQr = false;

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

  Future<void> _pickOutputDirectory() async {
    try {
      final String? directoryPath = await getDirectoryPath();
      if (directoryPath != null) {
        _addLog('Selected output directory: $directoryPath');
        setState(() {
          _outputDirectory = directoryPath;
        });
        _savePreference('outputDirectory', directoryPath);
      }
    } catch (e) {
      _addLog('Error picking directory: $e');
    }
  }

  Future<void> _pickLogoDirectory() async {
    try {
      final String? directoryPath =
          await getDirectoryPath(initialDirectory: _logoDirectory);
      if (directoryPath != null) {
        _addLog('Selected logo directory: $directoryPath');
        setState(() {
          _logoDirectory = directoryPath;
        });
        _savePreference('logoDirectory', directoryPath);
      }
    } catch (e) {
      _addLog('Error picking logo directory: $e');
    }
  }

  List<ProcessedFile> _processedFiles = <ProcessedFile>[];
  int _previewIndex = 0;
  CancellationToken? _cancellationToken;
  static const MethodChannel _platform = MethodChannel('secure_mark/sharing');
  Timer? _shareCheckTimer1;
  Timer? _shareCheckTimer2;

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? bookmarksJson = prefs.getString('identity_bookmarks');
    if (bookmarksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(bookmarksJson);
        setState(() {
          _identityBookmarks =
              decoded.map((item) => IdentityBookmark.fromJson(item)).toList();
        });
      } catch (e) {
        _addLog('Error loading bookmarks: $e');
      }
    }
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(_identityBookmarks.map((b) => b.toJson()).toList());
    await prefs.setString('identity_bookmarks', encoded);
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _transparency = prefs.getDouble('transparency') ?? 75.0;
          _density = prefs.getDouble('density') ?? 35.0;
          _fontSize = prefs.getDouble('fontSize') ?? 24.0;
          _jpegQuality = prefs.getInt('jpegQuality') ?? 75;
          // Default to 1280 if not set, unless explicitly set to null
          if (prefs.containsKey('targetSizeIsNull') &&
              prefs.getBool('targetSizeIsNull') == true) {
            _targetSize = null;
          } else {
            _targetSize = prefs.getInt('targetSize') ?? 1280;
          }
          _includeTimestamp = prefs.getBool('includeTimestamp') ?? true;
          _preserveMetadata = prefs.getBool('preserveMetadata') ?? false;
          _rasterizePdf = prefs.getBool('rasterizePdf') ?? false;
          _enablePdfSecurity = prefs.getBool('enablePdfSecurity') ?? false;
          _pdfAllowPrinting = prefs.getBool('pdfAllowPrinting') ?? false;
          _pdfAllowCopying = prefs.getBool('pdfAllowCopying') ?? false;
          _pdfAllowEditing = prefs.getBool('pdfAllowEditing') ?? false;
          _pdfUserPasswordController.text =
              prefs.getString('pdfUserPassword') ?? '';
          _pdfOwnerPasswordController.text =
              prefs.getString('pdfOwnerPassword') ?? '';
          _filePrefix = prefs.getString('filePrefix') ?? 'securemark-';
          _antiAiLevel = prefs.getDouble('antiAiLevel') ?? 50.0;
          _useAiCloaking = prefs.getBool('useAiCloaking') ?? false;
          _digitallySign = prefs.getBool('digitallySign') ?? false;
          _deviceName = prefs.getString('deviceName') ?? '';
          _deviceNameController.text = _deviceName;
          _useSteganography = prefs.getBool('useSteganography') ?? false;
          _useRobustSteganography =
              prefs.getBool('useRobustSteganography') ?? false;
          _hideFileWithSteganography =
              prefs.getBool('hideFileWithSteganography') ?? false;
          _zipOutputs = prefs.getBool('zipOutputs') ?? false;
          _useSecureZip = prefs.getBool('useSecureZip') ?? false;
          _secureZipPasswordController.text =
              prefs.getString('secureZipPassword') ?? '';
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

          // Load settings profile and apply its settings
          final profileIndex = prefs.getInt('selectedProfile') ?? 0;
          if (profileIndex >= 0 &&
              profileIndex < SettingsProfile.values.length) {
            _selectedProfile = SettingsProfile.values[profileIndex];
            // Apply the profile settings (will load profile-specific customizations)
            _loadProfileSettings(_selectedProfile);
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

          _steganographyTextController.text =
              prefs.getString('steganographyText') ?? '';

          _hiddenFileName = prefs.getString('hiddenFileName');
          final hiddenFileB64 = prefs.getString('hiddenFileBytes');
          if (hiddenFileB64 != null) {
            try {
              _hiddenFileBytes = base64Decode(hiddenFileB64);
            } catch (_) {
              _hiddenFileBytes = null;
            }
          }
          _logoDirectory = prefs.getString('logoDirectory');
          _outputDirectory = prefs.getString('outputDirectory');

          // Final safety check: if rasterizePdf is on, force-disable incompatible features
          if (_rasterizePdf) {
            _digitallySign = false;
            _useSteganography = false;
            _useRobustSteganography = false;
            _hideFileWithSteganography = false;
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
        // Clear the null flag if we're setting a value for targetSize
        if (key == 'targetSize') {
          await prefs.remove('targetSizeIsNull');
        }
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

  void _applyProfile(SettingsProfile profile) {
    setState(() {
      _selectedProfile = profile;

      // If not "None", reset all settings to defaults except QR data, output dir, and file prefix
      if (profile != SettingsProfile.none) {
        // Preserve QR code data
        final preservedQrAuthor = _qrAuthor;
        final preservedQrUrl = _qrUrl;
        final preservedQrType = _qrType;
        final preservedVCardFirstName = _vCardFirstName;
        final preservedVCardLastName = _vCardLastName;
        final preservedVCardPhone = _vCardPhone;
        final preservedVCardEmail = _vCardEmail;
        final preservedVCardOrg = _vCardOrg;
        final preservedQrPosition = _qrPosition;
        final preservedQrSize = _qrSize;
        final preservedQrOpacity = _qrOpacity;

        // Preserve PDF security settings
        final preservedEnablePdfSecurity = _enablePdfSecurity;
        final preservedPdfUserPassword = _pdfUserPasswordController.text;
        final preservedPdfOwnerPassword = _pdfOwnerPasswordController.text;
        final preservedPdfAllowPrinting = _pdfAllowPrinting;
        final preservedPdfAllowCopying = _pdfAllowCopying;
        final preservedPdfAllowEditing = _pdfAllowEditing;
        final preservedDigitallySign = _digitallySign;

        // Preserve output directory and file prefix
        final preservedOutputDir = _outputDirectory;
        final preservedFilePrefix = _filePrefix;
        final preservedZipOutputs = _zipOutputs;

        // Reset all settings to defaults
        _transparency = 75;
        _density = 35;
        _fontSize = 24;
        _logoSize = 100;
        _jpegQuality = 75;
        _targetSize = 1280;
        _includeTimestamp = true;
        _preserveMetadata = false;
        _rasterizePdf = false;
        _enablePdfSecurity = false;
        _pdfAllowPrinting = false;
        _pdfAllowCopying = false;
        _pdfAllowEditing = false;
        _pdfUserPasswordController.clear();
        _pdfOwnerPasswordController.clear();
        _digitallySign = false;
        _antiAiLevel = 50.0;
        _useSteganography = false;
        _useRobustSteganography = false;
        _useAiCloaking = false;
        _hideFileWithSteganography = false;
        _useRandomColor = true;
        _selectedColor = Colors.deepPurple;
        _selectedFont = WatermarkFont.arial;
        _qrVisible = false;
        _filePrefix = 'securemark-';
        _filePrefixController.text = _filePrefix;
        _zipOutputs = false;

        // Restore preserved values
        _qrAuthor = preservedQrAuthor;
        _qrUrl = preservedQrUrl;
        _qrType = preservedQrType;
        _vCardFirstName = preservedVCardFirstName;
        _vCardLastName = preservedVCardLastName;
        _vCardPhone = preservedVCardPhone;
        _vCardEmail = preservedVCardEmail;
        _vCardOrg = preservedVCardOrg;
        _qrPosition = preservedQrPosition;
        _qrSize = preservedQrSize;
        _qrOpacity = preservedQrOpacity;

        _enablePdfSecurity = preservedEnablePdfSecurity;
        _pdfUserPasswordController.text = preservedPdfUserPassword;
        _pdfOwnerPasswordController.text = preservedPdfOwnerPassword;
        _pdfAllowPrinting = preservedPdfAllowPrinting;
        _pdfAllowCopying = preservedPdfAllowCopying;
        _pdfAllowEditing = preservedPdfAllowEditing;
        _digitallySign = preservedDigitallySign;

        _outputDirectory = preservedOutputDir;
        _filePrefix = preservedFilePrefix;
        _zipOutputs = preservedZipOutputs;
      }

      // Apply profile-specific settings
      _loadProfileSettings(profile);
    });

    // Save all changed settings
    _savePreference('selectedProfile', profile.index);

    if (profile != SettingsProfile.none) {
      _saveAllCurrentSettings();
    }
  }

  void _loadProfileSettings(SettingsProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final String pKey = 'profile_${profile.name}_';

    setState(() {
      // General settings that apply to all profiles if they were customized
      if (prefs.containsKey('${pKey}transparency')) {
        _transparency = prefs.getDouble('${pKey}transparency')!;
      }
      if (prefs.containsKey('${pKey}density')) {
        _density = prefs.getDouble('${pKey}density')!;
      }
      if (prefs.containsKey('${pKey}jpegQuality')) {
        _jpegQuality = prefs.getInt('${pKey}jpegQuality')!;
      }
      if (prefs.containsKey('${pKey}targetSize')) {
        _targetSize = prefs.getInt('${pKey}targetSize');
      }
      if (prefs.containsKey('${pKey}antiAiLevel')) {
        _antiAiLevel = prefs.getDouble('${pKey}antiAiLevel')!;
      }
      if (prefs.containsKey('${pKey}useAiCloaking')) {
        _useAiCloaking = prefs.getBool('${pKey}useAiCloaking')!;
      }
      if (prefs.containsKey('${pKey}digitallySign')) {
        _digitallySign = prefs.getBool('${pKey}digitallySign')!;
      } else {
        _digitallySign = false;
      }
      if (prefs.containsKey('${pKey}useSteganography')) {
        _useSteganography = prefs.getBool('${pKey}useSteganography')!;
      }
      if (prefs.containsKey('${pKey}useRobustSteganography')) {
        _useRobustSteganography =
            prefs.getBool('${pKey}useRobustSteganography')!;
      }
      if (prefs.containsKey('${pKey}hideFileWithSteganography')) {
        _hideFileWithSteganography =
            prefs.getBool('${pKey}hideFileWithSteganography')!;
      }
      if (prefs.containsKey('${pKey}preserveMetadata')) {
        _preserveMetadata = prefs.getBool('${pKey}preserveMetadata')!;
      }
      if (prefs.containsKey('${pKey}qrVisible')) {
        _qrVisible = prefs.getBool('${pKey}qrVisible')!;
      }
      if (prefs.containsKey('${pKey}watermarkType')) {
        _watermarkType =
            WatermarkType.values[prefs.getInt('${pKey}watermarkType')!];
      }
      if (prefs.containsKey('${pKey}selectedColor')) {
        _selectedColor = Color(prefs.getInt('${pKey}selectedColor')!);
      }
      if (prefs.containsKey('${pKey}fontSize')) {
        _fontSize = prefs.getDouble('${pKey}fontSize')!;
      }
      if (prefs.containsKey('${pKey}filePrefix')) {
        _filePrefix = prefs.getString('${pKey}filePrefix')!;
        _filePrefixController.text = _filePrefix;
      }
      if (prefs.containsKey('${pKey}selectedFont')) {
        final fontFamily = prefs.getString('${pKey}selectedFont');
        if (fontFamily != null) {
          try {
            _selectedFont = WatermarkFont.values
                .firstWhere((f) => f.fontFamily == fontFamily);
          } catch (_) {}
        }
      }
      if (prefs.containsKey('${pKey}steganographyText')) {
        _steganographyTextController.text =
            prefs.getString('${pKey}steganographyText')!;
      }
      if (prefs.containsKey('${pKey}enablePdfSecurity')) {
        _enablePdfSecurity = prefs.getBool('${pKey}enablePdfSecurity')!;
      } else {
        _enablePdfSecurity = false;
      }
      if (prefs.containsKey('${pKey}pdfAllowPrinting')) {
        _pdfAllowPrinting = prefs.getBool('${pKey}pdfAllowPrinting')!;
      } else {
        _pdfAllowPrinting = false;
      }
      if (prefs.containsKey('${pKey}pdfAllowCopying')) {
        _pdfAllowCopying = prefs.getBool('${pKey}pdfAllowCopying')!;
      } else {
        _pdfAllowCopying = false;
      }
      if (prefs.containsKey('${pKey}pdfAllowEditing')) {
        _pdfAllowEditing = prefs.getBool('${pKey}pdfAllowEditing')!;
      } else {
        _pdfAllowEditing = false;
      }
      if (prefs.containsKey('${pKey}pdfUserPassword')) {
        _pdfUserPasswordController.text =
            prefs.getString('${pKey}pdfUserPassword')!;
      } else {
        _pdfUserPasswordController.clear();
      }
      if (prefs.containsKey('${pKey}pdfOwnerPassword')) {
        _pdfOwnerPasswordController.text =
            prefs.getString('${pKey}pdfOwnerPassword')!;
      } else {
        _pdfOwnerPasswordController.clear();
      }
      if (prefs.containsKey('${pKey}useSecureZip')) {
        _useSecureZip = prefs.getBool('${pKey}useSecureZip')!;
      } else {
        _useSecureZip = false;
      }
      if (prefs.containsKey('${pKey}secureZipPassword')) {
        _secureZipPasswordController.text =
            prefs.getString('${pKey}secureZipPassword')!;
      } else {
        _secureZipPasswordController.clear();
      }
      if (prefs.containsKey('${pKey}zipOutputs')) {
        _zipOutputs = prefs.getBool('${pKey}zipOutputs')!;
      }
      if (prefs.containsKey('${pKey}outputDirectory')) {
        _outputDirectory = prefs.getString('${pKey}outputDirectory');
      }
      if (prefs.containsKey('${pKey}useRandomColor')) {
        _useRandomColor = prefs.getBool('${pKey}useRandomColor')!;
      }
      if (prefs.containsKey('${pKey}rasterizePdf')) {
        _rasterizePdf = prefs.getBool('${pKey}rasterizePdf')!;
      }
      if (prefs.containsKey('${pKey}includeTimestamp')) {
        _includeTimestamp = prefs.getBool('${pKey}includeTimestamp')!;
      }
      if (prefs.containsKey('${pKey}logoSize')) {
        _logoSize = prefs.getDouble('${pKey}logoSize')!;
      }
      if (prefs.containsKey('${pKey}qrSize')) {
        _qrSize = prefs.getDouble('${pKey}qrSize')!;
      }
      if (prefs.containsKey('${pKey}qrOpacity')) {
        _qrOpacity = prefs.getDouble('${pKey}qrOpacity')!;
      }
      if (prefs.containsKey('${pKey}qrPosition')) {
        _qrPosition = QrPosition.values[prefs.getInt('${pKey}qrPosition')!];
      }
      if (prefs.containsKey('${pKey}qrType')) {
        _qrType = QrType.values[prefs.getInt('${pKey}qrType')!];
      }

      // Final safety check: if rasterizePdf is on, force-disable incompatible features
      if (_rasterizePdf) {
        _digitallySign = false;
        _useSteganography = false;
        _useRobustSteganography = false;
        _hideFileWithSteganography = false;
      }
    });

    // If no customization exists for a key, provide defaults for specific profiles
    setState(() {
      switch (profile) {
        case SettingsProfile.none:
          break;

        case SettingsProfile.secureIdentity:
          if (!prefs.containsKey('${pKey}targetSize')) _targetSize = 1280;
          if (!prefs.containsKey('${pKey}transparency')) _transparency = 65;
          if (!prefs.containsKey('${pKey}density')) _density = 35;
          if (!prefs.containsKey('${pKey}jpegQuality')) _jpegQuality = 75;
          if (!prefs.containsKey('${pKey}antiAiLevel')) _antiAiLevel = 100;
          if (!prefs.containsKey('${pKey}useAiCloaking')) _useAiCloaking = true;
          if (!prefs.containsKey('${pKey}digitallySign')) _digitallySign = true;
          if (!prefs.containsKey('${pKey}watermarkType')) {
            _watermarkType = WatermarkType.text;
          }
          if (!prefs.containsKey('${pKey}filePrefix')) {
            _filePrefix = 'id-';
            _filePrefixController.text = _filePrefix;
          }
          break;

        case SettingsProfile.onlineImage:
          if (!prefs.containsKey('${pKey}useSteganography')) {
            _useSteganography = true;
          }
          if (!prefs.containsKey('${pKey}useRobustSteganography')) {
            _useRobustSteganography = true;
          }
          if (!prefs.containsKey('${pKey}useAiCloaking')) {
            _useAiCloaking = false;
          }
          if (!prefs.containsKey('${pKey}transparency')) {
            _transparency = 80;
          }
          if (!prefs.containsKey('${pKey}targetSize')) {
            _targetSize = 1280;
          }
          if (!prefs.containsKey('${pKey}jpegQuality')) {
            _jpegQuality = 75;
          }
          if (!prefs.containsKey('${pKey}filePrefix')) {
            _filePrefix = 'web-';
            _filePrefixController.text = _filePrefix;
          }
          break;

        case SettingsProfile.qrCode:
          if (!prefs.containsKey('${pKey}qrVisible')) {
            _qrVisible = true;
          }
          if (!prefs.containsKey('${pKey}transparency')) {
            _transparency = 100;
          }
          if (!prefs.containsKey('${pKey}useSteganography')) {
            _useSteganography = false;
          }
          if (!prefs.containsKey('${pKey}useRobustSteganography')) {
            _useRobustSteganography = false;
          }
          if (!prefs.containsKey('${pKey}hideFileWithSteganography')) {
            _hideFileWithSteganography = false;
          }
          if (!prefs.containsKey('${pKey}antiAiLevel')) {
            _antiAiLevel = 0;
          }
          if (!prefs.containsKey('${pKey}useAiCloaking')) {
            _useAiCloaking = false;
          }
          if (!prefs.containsKey('${pKey}targetSize')) {
            _targetSize = 1600;
          }
          if (!prefs.containsKey('${pKey}preserveMetadata')) {
            _preserveMetadata = false;
          }
          if (!prefs.containsKey('${pKey}filePrefix')) {
            _filePrefix = 'qrcode-';
            _filePrefixController.text = _filePrefix;
          }
          break;

        case SettingsProfile.shareDocument:
          if (!prefs.containsKey('${pKey}targetSize')) _targetSize = 1280;
          if (!prefs.containsKey('${pKey}transparency')) _transparency = 50;
          if (!prefs.containsKey('${pKey}density')) _density = 40;
          if (!prefs.containsKey('${pKey}jpegQuality')) _jpegQuality = 80;
          if (!prefs.containsKey('${pKey}antiAiLevel')) _antiAiLevel = 75;
          if (!prefs.containsKey('${pKey}useAiCloaking')) _useAiCloaking = true;
          if (!prefs.containsKey('${pKey}filePrefix')) {
            _filePrefix = 'doc-';
            _filePrefixController.text = _filePrefix;
          }
          break;

        case SettingsProfile.p1:
          if (!prefs.containsKey('${pKey}targetSize')) {
            _targetSize = 1280;
          }
          if (!prefs.containsKey('${pKey}transparency')) {
            _transparency = 75;
          }
          if (!prefs.containsKey('${pKey}density')) {
            _density = 35;
          }
          if (!prefs.containsKey('${pKey}jpegQuality')) {
            _jpegQuality = 75;
          }
          if (!prefs.containsKey('${pKey}antiAiLevel')) {
            _antiAiLevel = 50;
          }
          if (!prefs.containsKey('${pKey}useAiCloaking')) {
            _useAiCloaking = false;
          }
          if (!prefs.containsKey('${pKey}filePrefix')) {
            _filePrefix = 'p1-';
            _filePrefixController.text = _filePrefix;
          }
          break;
      }
    });
  }

  void _saveAllCurrentSettings() {
    _savePreference('transparency', _transparency);
    _savePreference('density', _density);
    _savePreference('fontSize', _fontSize);
    _savePreference('jpegQuality', _jpegQuality);
    _savePreference('targetSize', _targetSize);
    _savePreference('includeTimestamp', _includeTimestamp);
    _savePreference('preserveMetadata', _preserveMetadata);
    _savePreference('rasterizePdf', _rasterizePdf);
    _savePreference('antiAiLevel', _antiAiLevel);
    _savePreference('useSteganography', _useSteganography);
    _savePreference('useRobustSteganography', _useRobustSteganography);
    _savePreference('digitallySign', _digitallySign);
    _savePreference('useAiCloaking', _useAiCloaking);
    _savePreference('deviceName', _deviceNameController.text);
    _savePreference('hideFileWithSteganography', _hideFileWithSteganography);
    _savePreference('useRandomColor', _useRandomColor);
    _savePreference('selectedColor', _selectedColor.toARGB32());
    _savePreference('selectedFont', _selectedFont.fontFamily);
    _savePreference('qrVisible', _qrVisible);
    _savePreference('filePrefix', _filePrefix);
    _savePreference('steganographyText', _steganographyTextController.text);
    _savePreference('enablePdfSecurity', _enablePdfSecurity);
    _savePreference('pdfAllowPrinting', _pdfAllowPrinting);
    _savePreference('pdfAllowCopying', _pdfAllowCopying);
    _savePreference('pdfAllowEditing', _pdfAllowEditing);
    _savePreference('pdfUserPassword', _pdfUserPasswordController.text);
    _savePreference('pdfOwnerPassword', _pdfOwnerPasswordController.text);
    _savePreference('useSecureZip', _useSecureZip);
    _savePreference('secureZipPassword', _secureZipPasswordController.text);
    _savePreference('zipOutputs', _zipOutputs);
  }

  Future<void> _saveCurrentConfigToProfile(SettingsProfile profile) async {
    if (profile == SettingsProfile.none) return;

    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final String pKey = 'profile_${profile.name}_';

    await prefs.setDouble('${pKey}transparency', _transparency);
    await prefs.setDouble('${pKey}density', _density);
    await prefs.setInt('${pKey}jpegQuality', _jpegQuality);
    if (_targetSize != null) {
      await prefs.setInt('${pKey}targetSize', _targetSize!);
    } else {
      await prefs.remove('${pKey}targetSize');
    }
    await prefs.setDouble('${pKey}antiAiLevel', _antiAiLevel);
    await prefs.setBool('${pKey}useAiCloaking', _useAiCloaking);
    await prefs.setBool('${pKey}useSteganography', _useSteganography);
    await prefs.setBool(
        '${pKey}useRobustSteganography', _useRobustSteganography);
    await prefs.setBool('${pKey}digitallySign', _digitallySign);
    await prefs.setBool(
        '${pKey}hideFileWithSteganography', _hideFileWithSteganography);
    await prefs.setBool('${pKey}preserveMetadata', _preserveMetadata);
    await prefs.setBool('${pKey}qrVisible', _qrVisible);
    await prefs.setInt('${pKey}watermarkType', _watermarkType.index);

    // Additional requested settings
    await prefs.setInt('${pKey}selectedColor', _selectedColor.toARGB32());
    await prefs.setDouble('${pKey}fontSize', _fontSize);
    await prefs.setString('${pKey}filePrefix', _filePrefix);
    await prefs.setString('${pKey}selectedFont', _selectedFont.fontFamily);
    await prefs.setString(
        '${pKey}steganographyText', _steganographyTextController.text);
    if (_outputDirectory != null) {
      await prefs.setString('${pKey}outputDirectory', _outputDirectory!);
    } else {
      await prefs.remove('${pKey}outputDirectory');
    }
    await prefs.setBool('${pKey}useRandomColor', _useRandomColor);
    await prefs.setBool('${pKey}rasterizePdf', _rasterizePdf);
    await prefs.setBool('${pKey}includeTimestamp', _includeTimestamp);
    await prefs.setDouble('${pKey}logoSize', _logoSize);
    await prefs.setDouble('${pKey}qrSize', _qrSize);
    await prefs.setDouble('${pKey}qrOpacity', _qrOpacity);
    await prefs.setInt('${pKey}qrPosition', _qrPosition.index);
    await prefs.setInt('${pKey}qrType', _qrType.index);
    await prefs.setBool('${pKey}enablePdfSecurity', _enablePdfSecurity);
    await prefs.setBool('${pKey}pdfAllowPrinting', _pdfAllowPrinting);
    await prefs.setBool('${pKey}pdfAllowCopying', _pdfAllowCopying);
    await prefs.setBool('${pKey}pdfAllowEditing', _pdfAllowEditing);
    await prefs.setString(
        '${pKey}pdfUserPassword', _pdfUserPasswordController.text);
    await prefs.setString(
        '${pKey}pdfOwnerPassword', _pdfOwnerPasswordController.text);
    await prefs.setBool('${pKey}useSecureZip', _useSecureZip);
    await prefs.setString(
        '${pKey}secureZipPassword', _secureZipPasswordController.text);

    if (mounted) {
      String profileLabel = '';
      switch (profile) {
        case SettingsProfile.secureIdentity:
          profileLabel = l10n.profileSecureIdentity;
        case SettingsProfile.onlineImage:
          profileLabel = l10n.profileOnlineImage;
        case SettingsProfile.qrCode:
          profileLabel = l10n.profileQrCode;
        case SettingsProfile.shareDocument:
          profileLabel = l10n.profileShareDocument;
        default:
          profileLabel = profile.name;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileSaved(profileLabel)),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _resetProfileToDefaults(SettingsProfile profile) async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final String pKey = 'profile_${profile.name}_';

    final keys = prefs.getKeys().where((k) => k.startsWith(pKey)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }

    if (mounted) {
      String profileLabel = '';
      switch (profile) {
        case SettingsProfile.secureIdentity:
          profileLabel = l10n.profileSecureIdentity;
        case SettingsProfile.onlineImage:
          profileLabel = l10n.profileOnlineImage;
        case SettingsProfile.qrCode:
          profileLabel = l10n.profileQrCode;
        case SettingsProfile.shareDocument:
          profileLabel = l10n.profileShareDocument;
        default:
          profileLabel = profile.name;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileReset(profileLabel)),
        ),
      );

      if (_selectedProfile == profile) {
        _applyProfile(profile);
      }
    }
  }

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
    _initOutputDirectory();
    IdentityManager.onLog = _addLog;
    IdentityManager.getIdentityKeyPair().then((_) async {
      final pk = await IdentityManager.getDevicePublicKey();
      if (mounted) setState(() => _devicePublicKey = pk);
    });

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

          final isValid =
              await WatermarkProcessor.isSupportedFile(File(filePath));

          _addLog('[$i] File support valid: $isValid');

          if (!isValid) {
            _addLog('[$i] ❌ Unsupported file format or extension');
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

  ProcessedFile? get _currentProcessedFile {
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
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              onPressed: _processing ||
                      _selectedPaths.isEmpty ||
                      (_watermarkType == WatermarkType.image &&
                          _watermarkImageBytes == null)
                  ? null
                  : _applyWatermark,
              tooltip: l10n.applyWatermark,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: _showFileAnalyzer,
              tooltip: l10n.analyzeFile,
            ),
            IconButton(
              icon: const Icon(Icons.verified_user_outlined),
              onPressed: _showSteganographyOptions,
              tooltip: l10n.steganographyTitle,
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_2),
              onPressed: _showQrWatermarkOptions,
              tooltip: l10n.qrWatermarkTitle,
            ),
            IconButton(
              icon: const Icon(Icons.font_download_outlined),
              onPressed: _showFontOptions,
              tooltip: l10n.fontConfigTitle,
            ),
            IconButton(
              icon: const Icon(Icons.person_pin_outlined),
              onPressed: _showIdentityDialog,
              tooltip: l10n.myIdentityTitle,
            ),
            IconButton(
              icon: const Icon(Icons.sensors),
              onPressed: _showLocalShareDialog,
              tooltip: l10n.localShareTitle,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            onPressed: _showExpertOptions,
            tooltip: l10n.expertOptions,
          ),
        ],
        centerTitle: false,
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

  Widget _buildProfileSelector(ThemeData theme, AppLocalizations l10n) {
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

    final chips = SettingsProfile.values.map((profile) {
      final isSelected = _selectedProfile == profile;
      String label;
      IconData icon;

      switch (profile) {
        case SettingsProfile.none:
          label = l10n.profileNone;
          icon = Icons.not_interested;
        case SettingsProfile.secureIdentity:
          label = l10n.profileSecureIdentity;
          icon = Icons.fingerprint;
        case SettingsProfile.onlineImage:
          label = l10n.profileOnlineImage;
          icon = Icons.public;
        case SettingsProfile.qrCode:
          label = l10n.profileQrCode;
          icon = Icons.qr_code;
        case SettingsProfile.shareDocument:
          label = l10n.profileShareDocument;
          icon = Icons.description;
        case SettingsProfile.p1:
          label = "P1";
          icon = Icons.person_outline;
      }

      return ProfileChip(
        profile: profile,
        label: label,
        icon: icon,
        isSelected: isSelected,
        isDisabled: _processing,
        onSelected: () => _applyProfile(profile),
        onLongPress: () => _saveCurrentConfigToProfile(profile),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4.0),
        if (isMobile)
          Stack(
            alignment: Alignment.center,
            children: [
              ShaderMask(
                shaderCallback: (Rect rect) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.purple,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.purple
                    ],
                    stops: [0.0, 0.05, 0.95, 1.0], // 5% fade on both sides
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstOut,
                child: SingleChildScrollView(
                  controller: _profileScrollController,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(children: chips),
                  ),
                ),
              ),
              // Left Indicator Arrow
              Positioned(
                left: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _profileScrollController.hasClients &&
                            _profileScrollController.offset > 5
                        ? 1.0
                        : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            theme.colorScheme.surface,
                            theme.colorScheme.surface.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: Icon(Icons.chevron_left,
                          size: 20, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              ),
              // Right Indicator Arrow
              Positioned(
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _profileScrollController.hasClients &&
                            _profileScrollController.offset <
                                _profileScrollController
                                        .position.maxScrollExtent -
                                    5
                        ? 1.0
                        : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            theme.colorScheme.surface,
                            theme.colorScheme.surface.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: Icon(Icons.chevron_right,
                          size: 20, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Wrap(
            children: chips,
          ),
      ],
    );
  }

  Widget _buildControlsPanel(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileSelector(theme, l10n),
        const SizedBox(height: 16),
        _buildPrimaryActionCard(),
        const SizedBox(height: 16),
        _buildCombinedWatermarkCard(),
        const SizedBox(height: 16),
        if (_buildStatusIcons(l10n) != null) ...[
          _buildStatusIcons(l10n)!,
          const SizedBox(height: 16),
        ],
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

    // Let the user choose a location, but if they cancel, save to default internal storage.
    FileSaveLocation? selectedLocation;
    try {
      selectedLocation = await getSaveLocation(suggestedName: suggestedName);
    } catch (_) {
      selectedLocation = null;
    }

    String logPath;
    if (selectedLocation != null) {
      logPath = selectedLocation.path;
    } else {
      // Default: write directly to the app's documents directory (no UI prompt).
      final docsDir = await getApplicationDocumentsDirectory();
      logPath = '${docsDir.path}/securemark_logs_$timestamp.txt';
    }

    final logContent = _logs.join('\n');

    try {
      if (selectedLocation != null) {
        final logFile = XFile.fromData(
          Uint8List.fromList(utf8.encode(logContent)),
          name: suggestedName,
          mimeType: 'text/plain',
        );
        await logFile.saveTo(logPath);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.logsSaved(p.basename(logPath))),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        final File defaultFile = File(logPath);
        await defaultFile.writeAsString(logContent);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logs saved to ${p.basename(logPath)}'),
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
                  const SizedBox(height: 16),
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
        final latestTag = data['tag_name'] as String;

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

    setState(() {
      _extractionPassword = '';
      _extractionPasswordController.text = '';
      // Reset analysis state
      _analysisResult = null;
      _extractedFile = null;
      _batchAnalysisResult = null;
      _selectedFileIndex = null;
      _extractedSignature = null;
      _verificationResult = null;
      _integrityVerified = false;
      _senderPublicKey = null;
      _analyzingFile = false;
    });

    showDialog(
      context: context,
      builder: (context) {
        bool isDragging = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);

            Widget dialogContent = SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showIdentityBookmarksDialog(),
                    icon: const Icon(Icons.bookmarks_outlined),
                    label: Text(l10n.identityBookmarksTitle),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: _obscureExtractionPassword,
                    decoration: InputDecoration(
                      labelText: l10n.steganographyPasswordLabel,
                      hintText: l10n.steganographyPasswordHint,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureExtractionPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          final newValue = !_obscureExtractionPassword;
                          setDialogState(() {
                            _obscureExtractionPassword = newValue;
                          });
                          setState(() {
                            _obscureExtractionPassword = newValue;
                          });
                        },
                      ),
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
                  if (!_analyzingFile &&
                      _analysisResult == null &&
                      _batchAnalysisResult == null) ...[
                    const SizedBox(height: 16),
                    Text(l10n.fileAnalyzerDescription),
                  ],
                  const SizedBox(height: 24),
                  if (_analyzingFile)
                    const CircularProgressIndicator()
                  else if (_batchAnalysisResult != null)
                    _buildBatchAnalysisView(setDialogState, theme, l10n)
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
                                  icon:
                                      const Icon(Icons.copy_rounded, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: l10n.copySignature,
                                  onPressed: () {
                                    final textToCopy = _extractedSignature ??
                                        (_analysisResult!.contains(': ')
                                            ? _analysisResult!
                                                .split(': ')
                                                .sublist(1)
                                                .join(': ')
                                            : _analysisResult!);
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
                          if (_verificationResult != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _verificationResult!.isAuthentic
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _verificationResult!.isAuthentic
                                      ? Colors.green
                                      : Colors.red,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _verificationResult!.isAuthentic
                                            ? Icons.verified_user
                                            : Icons.gpp_maybe,
                                        color: _verificationResult!.isAuthentic
                                            ? Colors.green
                                            : Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _verificationResult!
                                                  .isContentAuthentic
                                              ? l10n.fullAuthenticityConfirmed
                                              : _verificationResult!
                                                      .isSourceAuthentic
                                                  ? l10n.partialAuthenticity
                                                  : l10n.tamperingDetected,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _verificationResult!.isAuthentic
                                                    ? Colors.green
                                                    : Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildForensicRow(
                                    label: l10n.forensicLayerContent,
                                    isValid:
                                        _verificationResult!.isContentAuthentic,
                                    l10n: l10n,
                                  ),
                                  const SizedBox(height: 4),
                                  _buildForensicRow(
                                    label: l10n.forensicLayerSource,
                                    isValid:
                                        _verificationResult!.isSourceAuthentic,
                                    l10n: l10n,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _getLocalizedVerificationMessage(
                                        _verificationResult!, l10n),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Signed on: ${_verificationResult!.timestamp.toString().split('.').first}',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_senderPublicKey != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _integrityVerified
                                    ? Colors.blue.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _integrityVerified
                                      ? Colors.blue
                                      : Colors.orange,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _integrityVerified
                                            ? Icons.verified
                                            : Icons.report_problem_outlined,
                                        color: _integrityVerified
                                            ? Colors.blue
                                            : Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _integrityVerified
                                              ? l10n.signatureVerified
                                              : l10n.tamperDetected,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _integrityVerified
                                                ? Colors.blue
                                                : Colors.orange,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _senderPublicKey ==
                                                      _devicePublicKey
                                                  ? l10n.senderOwnerLabel(
                                                      'Me (${_deviceName.isNotEmpty ? _deviceName : 'This Device'})')
                                                  : _identityBookmarks.any(
                                                          (b) =>
                                                              b.publicKey ==
                                                              _senderPublicKey)
                                                      ? l10n.senderOwnerLabel(
                                                          _identityBookmarks
                                                              .firstWhere((b) =>
                                                                  b.publicKey ==
                                                                  _senderPublicKey)
                                                              .name)
                                                      : 'Sender ID: ${_senderPublicKey!.substring(0, 8)}...${_senderPublicKey!.substring(_senderPublicKey!.length - 8)}',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: _senderPublicKey ==
                                                            _devicePublicKey ||
                                                        _identityBookmarks.any(
                                                            (b) =>
                                                                b.publicKey ==
                                                                _senderPublicKey)
                                                    ? Colors.blue
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              _identityBookmarks.any((b) =>
                                                      b.publicKey ==
                                                      _senderPublicKey)
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_add_outlined,
                                              size: 18,
                                              color: _identityBookmarks.any(
                                                      (b) =>
                                                          b.publicKey ==
                                                          _senderPublicKey)
                                                  ? Colors.blue
                                                  : null,
                                            ),
                                            tooltip: 'Bookmark this identity',
                                            onPressed: () async {
                                              if (!_identityBookmarks.any((b) =>
                                                  b.publicKey ==
                                                  _senderPublicKey)) {
                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                        context);
                                                final nameController =
                                                    TextEditingController();
                                                final save =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title: const Text(
                                                        'Bookmark Identity'),
                                                    content: TextField(
                                                      controller:
                                                          nameController,
                                                      decoration:
                                                          const InputDecoration(
                                                        labelText: 'Name',
                                                        hintText:
                                                            'e.g. John Doe',
                                                      ),
                                                      autofocus: true,
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: const Text(
                                                            'Cancel'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child:
                                                            const Text('Save'),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (save == true &&
                                                    nameController
                                                        .text.isNotEmpty) {
                                                  setDialogState(() {
                                                    _identityBookmarks.add(
                                                        IdentityBookmark(
                                                            name: nameController
                                                                .text,
                                                            publicKey:
                                                                _senderPublicKey!));
                                                  });
                                                  _saveBookmarks();
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                        content: Text(l10n
                                                            .bookmarkSaved)),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy,
                                                size: 18),
                                            tooltip: l10n.copyPublicKey,
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(
                                                  text: _senderPublicKey!));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        l10n.publicKeyCopied)),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                    Icon(
                        isDragging
                            ? Icons.file_download
                            : Icons.insert_drive_file_outlined,
                        size: 48,
                        color: isDragging
                            ? theme.colorScheme.primary
                            : Colors.grey),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _analyzingFile
                        ? null
                        : () => _pickAndAnalyze(setDialogState),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      backgroundColor: isDragging
                          ? theme.colorScheme.primary.withValues(alpha: 0.8)
                          : null,
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isDragging
                            ? BorderSide(
                                color: theme.colorScheme.onPrimary, width: 2)
                            : BorderSide.none,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isDragging ? Icons.file_upload : Icons.file_open,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isDragging
                              ? l10n.desktopDropArea
                              : l10n.pickAndAnalyze,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            if (_supportsDesktopDrop) {
              dialogContent = DropTarget(
                onDragEntered: (_) => setDialogState(() => isDragging = true),
                onDragExited: (_) => setDialogState(() => isDragging = false),
                onDragDone: (detail) async {
                  setDialogState(() => isDragging = false);
                  if (detail.files.isEmpty) return;
                  final file = detail.files.first;
                  try {
                    final bytes = await file.readAsBytes();
                    await _performFileAnalysis(
                        bytes, file.name, setDialogState);
                  } catch (e) {
                    setDialogState(() {
                      _analysisResult = l10n.analysisError(e.toString());
                    });
                  }
                },
                child: dialogContent,
              );
            }

            return AlertDialog(
              insetPadding: MediaQuery.of(context).size.width < 600
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
                  : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              title: Row(
                children: [
                  const Icon(Icons.search_rounded),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.fileAnalyzerTitle)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: dialogContent,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _analysisResult = null;
                    _extractedFile = null;
                    _batchAnalysisResult = null;
                    _selectedFileIndex = null;
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _analyzingFile = false;
  String? _analysisResult;
  String? _extractedSignature;
  VerificationResult? _verificationResult;
  bool _integrityVerified = false;
  String? _senderPublicKey;
  ExtractedFileResult? _extractedFile;
  BatchAnalysisResult? _batchAnalysisResult;
  int? _selectedFileIndex;

  Future<void> _pickAndAnalyze(StateSetter setDialogState) async {
    // Reset state FIRST before picking new file
    setDialogState(() {
      _analysisResult = null;
      _extractedFile = null;
      _batchAnalysisResult = null;
      _selectedFileIndex = null;
      _extractedSignature = null;
      _verificationResult = null;
      _integrityVerified = false;
      _senderPublicKey = null;
      _analyzingFile = false;
    });

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'pdf',
        'heic',
        'heif',
        'zip'
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final pickedFile = result.files.single;

    try {
      final bytes =
          pickedFile.bytes ?? await File(pickedFile.path!).readAsBytes();
      if (!mounted) return;

      // Check if it's a ZIP file
      final extension = p.extension(pickedFile.name).toLowerCase();
      if (extension == '.zip') {
        await _performBatchAnalysis(bytes, pickedFile.name, setDialogState);
      } else {
        await _performFileAnalysis(bytes, pickedFile.name, setDialogState);
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setDialogState(() {
        _analysisResult = l10n.analysisError(e.toString());
      });
    }
  }

  void _showIdentityBookmarksDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.bookmarks_outlined, color: Colors.blue),
                  const SizedBox(width: 12),
                  Text(l10n.identityBookmarksTitle),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                _identityBookmarks.add(
                                    IdentityBookmark(name: '', publicKey: ''));
                              });
                              _saveBookmarks();
                            },
                            icon: const Icon(Icons.add),
                            label: Text(l10n.addIdentity),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showIdentityQrScanner(setDialogState),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text(l10n.addWithQrCode),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_identityBookmarks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(l10n.noBookmarksYet),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _identityBookmarks.length,
                          itemBuilder: (context, index) {
                            final bookmark = _identityBookmarks[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: l10n.identityNameLabel,
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        _identityBookmarks[index] =
                                            IdentityBookmark(
                                                name: val,
                                                publicKey: bookmark.publicKey);
                                        _saveBookmarks();
                                      },
                                      controller: TextEditingController(
                                          text: bookmark.name)
                                        ..selection =
                                            TextSelection.fromPosition(
                                                TextPosition(
                                                    offset:
                                                        bookmark.name.length)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: l10n.identityKeyLabel,
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        _identityBookmarks[index] =
                                            IdentityBookmark(
                                                name: bookmark.name,
                                                publicKey: val);
                                        _saveBookmarks();
                                      },
                                      controller: TextEditingController(
                                          text: bookmark.publicKey)
                                        ..selection =
                                            TextSelection.fromPosition(
                                                TextPosition(
                                                    offset: bookmark
                                                        .publicKey.length)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(l10n.delete),
                                          content:
                                              Text(l10n.removeIdentityConfirm),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(l10n.cancel),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text(l10n.delete,
                                                  style: const TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        setDialogState(() {
                                          _identityBookmarks.removeAt(index);
                                        });
                                        _saveBookmarks();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLocalShareDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Get local IPs
    _localIps = await LocalServerManager.getLocalIps();
    _selectedLocalIpIndex = 0;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.sensors, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(l10n.localShareTitle),
                  ],
                ),
                content: SizedBox(
                  width: 700,
                  height: 600,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(
                              text: l10n.sendTab,
                              icon: const Icon(Icons.upload_file)),
                          Tab(
                              text: l10n.receiveTab,
                              icon: const Icon(Icons.download_for_offline)),
                        ],
                        labelColor: theme.colorScheme.primary,
                        unselectedLabelColor:
                            theme.colorScheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Send Tab
                            _buildSendTab(setDialogState),
                            // Receive Tab
                            _buildReceiveTab(setDialogState),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      LocalServerManager.stopServer();
                      setState(() {
                        _servingPort = 0;
                        _sendingFileName = null;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(l10n.close),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<Uint8List> _createProcessedZipBytes() async {
    final archive = Archive();
    for (final file in _processedFiles) {
      final fileName = p.basename(file.result.outputPath);
      archive.addFile(ArchiveFile(
          fileName, file.result.outputBytes.length, file.result.outputBytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Widget _buildSendTab(StateSetter setDialogState) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final isRunning = LocalServerManager.isRunning;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          if (!isRunning) ...[
            // Encryption Toggle
            SwitchListTile(
              title: Text(l10n.enableEncryption,
                  style: const TextStyle(fontSize: 14)),
              subtitle: !_useLocalEncryption
                  ? Text(l10n.encryptionDisabledWarning,
                      style: TextStyle(
                          color: theme.colorScheme.error, fontSize: 11))
                  : null,
              value: _useLocalEncryption,
              onChanged: (val) {
                setDialogState(() => _useLocalEncryption = val);
              },
            ),
            const Divider(),

            // Pick Custom File Button
            ListTile(
              title: Text(l10n.pickAnyFile,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.file_open_outlined),
              onTap: () async {
                final result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  final bytes = await file.readAsBytes();
                  final fileName = result.files.single.name;
                  await _startServingEncrypted(bytes, fileName, setDialogState);
                }
              },
            ),
            const Divider(),

            if (_processedFiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  l10n.noFilesToSend,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else ...[
              Text(l10n.localShareInstructions,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              if (_processedFiles.length > 1) ...[
                ListTile(
                  title: Text(l10n.sendAllZip,
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                  leading: Icon(Icons.folder_zip_outlined,
                      color: theme.colorScheme.primary),
                  onTap: () async {
                    final bytes = await _createProcessedZipBytes();
                    final fileName = 'securemark_batch.zip';
                    await _startServingEncrypted(
                        bytes, fileName, setDialogState);
                  },
                ),
                const Divider(),
              ],
              // File list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _processedFiles.length,
                itemBuilder: (context, index) {
                  final file = _processedFiles[index];
                  final fileName = p.basename(file.result.outputPath);
                  return ListTile(
                    title: Text(fileName, style: const TextStyle(fontSize: 14)),
                    leading: const Icon(Icons.description_outlined),
                    onTap: () async {
                      final bytes = file.result.outputBytes;
                      await _startServingEncrypted(
                          bytes, fileName, setDialogState);
                    },
                  );
                },
              ),
            ],
          ] else ...[
            Text(l10n.sendingFile(_sendingFileName ?? '')),
            const SizedBox(height: 8),
            if (_localIps.length > 1)
              DropdownButton<int>(
                value: _selectedLocalIpIndex,
                isExpanded: true,
                items: List.generate(
                    _localIps.length,
                    (i) => DropdownMenuItem(
                          value: i,
                          child: Text(_localIps[i]),
                        )),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => _selectedLocalIpIndex = val);
                  }
                },
              )
            else if (_localIps.isNotEmpty)
              Text(_localIps.first,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data:
                    'http://${_localIps[_selectedLocalIpIndex]}:$_servingPort/${LocalServerManager.token}/download?key=$_localEncryptionKey',
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.manualUrlLabel, style: const TextStyle(fontSize: 11)),
            SelectableText(
              'http://${_localIps[_selectedLocalIpIndex]}:$_servingPort/${LocalServerManager.token}/download${_localEncryptionKey != null ? "?key=$_localEncryptionKey" : ""}',
              style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                LocalServerManager.stopServer();
                setDialogState(() {
                  _servingPort = 0;
                  _sendingFileName = null;
                });
              },
              icon: const Icon(Icons.stop),
              label: Text(l10n.reset),
              style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiveTab(StateSetter setDialogState) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_showReceiveQr) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(l10n.waitingForFile,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_localIps.length > 1)
            DropdownButton<int>(
              value: _selectedLocalIpIndex,
              isExpanded: true,
              items: List.generate(
                  _localIps.length,
                  (i) => DropdownMenuItem(
                        value: i,
                        child: Text(_localIps[i]),
                      )),
              onChanged: (val) {
                if (val != null) {
                  setDialogState(() => _selectedLocalIpIndex = val);
                }
              },
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: QrImageView(
              data:
                  'securemark://receive?addr=${_localIps[_selectedLocalIpIndex]}&port=$_servingPort&token=${LocalServerManager.token}',
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.showQrToReceive,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              LocalServerManager.stopServer();
              setDialogState(() => _showReceiveQr = false);
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text("Back to Camera"),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.5), width: 2),
            ),
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    if (code.startsWith('http') && code.contains('/download')) {
                      Navigator.pop(context);
                      _downloadFromLocalUrl(code);
                    } else if (code.startsWith('securemark://receive')) {
                      Navigator.pop(context);
                      _handleReversePush(code);
                    }
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Target Directory Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.saveToWhere,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _outputDirectory ?? "Default Storage (Gallery/Downloads)",
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await _pickOutputDirectory();
                  setDialogState(() {});
                },
                icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                label: Text(l10n.selectOutputDirectory),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(double.infinity, 32),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.localShareInstructions, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final port = await LocalServerManager.startReceiveServer(
                (bytes, name, addr) {
              _addLog('Received file $name from $addr');
              _saveDownloadedFile(bytes, name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.fileReceived(addr))),
                );
              }
            }, onDone: () {
              if (mounted) {
                setDialogState(() {
                  _servingPort = 0;
                  _showReceiveQr = false;
                });
              }
            });
            setDialogState(() {
              _servingPort = port;
              _showReceiveQr = true;
            });
          },
          icon: const Icon(Icons.qr_code_2),
          label: Text(l10n.noCameraOption),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _handleReversePush(String qrData) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Parse: securemark://receive?addr=...&port=...&token=...
    final uri = Uri.parse(qrData.replaceFirst('securemark://', 'http://'));
    final addr = uri.queryParameters['addr'];
    final port = uri.queryParameters['port'];
    final token = uri.queryParameters['token'];

    if (addr == null || port == null || token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Invalid Receiver QR'),
              backgroundColor: theme.colorScheme.error),
        );
      }
      return;
    }

    // 1. Pick file to send
    Uint8List? fileBytes;
    String? fileName;

    if (_processedFiles.length == 1) {
      fileBytes = _processedFiles.first.result.outputBytes;
      fileName = p.basename(_processedFiles.first.result.outputPath);
    } else {
      // Multiple or zero processed, ask user to pick
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        fileBytes = await File(result.files.single.path!).readAsBytes();
        fileName = result.files.single.name;
      }
    }

    if (fileBytes == null || fileName == null) return;

    if (!mounted) return;

    // 2. Perform PUSH (POST)
    _elapsedTime = '00:00';
    _startStopwatch();

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setProgressState) {
          _progressListener = () {
            if (mounted) setProgressState(() {});
          };
          return AlertDialog(
            title: Text(l10n.localShareTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(l10n.pushingFile(addr), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_elapsedTime,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );

    try {
      final uploadUrl = 'http://$addr:$port/$token/upload';
      final request = http.Request('POST', Uri.parse(uploadUrl));
      request.headers['x-file-name'] = fileName;
      request.bodyBytes = fileBytes;

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      _stopStopwatch();
      _progressListener = null;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File sent successfully!')),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _stopStopwatch();
      _progressListener = null;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Push failed: $e'),
              backgroundColor: theme.colorScheme.error),
        );
      }
    }
  }

  Future<void> _startServingEncrypted(
      Uint8List bytes, String fileName, StateSetter setDialogState) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    List<String> progressLogs = [];
    double progress = 0.0;

    void addLog(String msg) {
      progressLogs.add(msg);
      _progressListener?.call();
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setProgressState) {
          _progressListener = () {
            if (mounted) setProgressState(() {});
          };
          return AlertDialog(
            title: Text(l10n.localShareTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: progressLogs.length,
                    reverse: true,
                    itemBuilder: (context, i) => Text(
                      progressLogs[progressLogs.length - 1 - i],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      if (_useLocalEncryption) {
        addLog(l10n.generatingKey);
        final key = LocalServerManager.token ??
            'sm-${DateTime.now().millisecondsSinceEpoch}';
        _localEncryptionKey = key;
        await Future.delayed(const Duration(milliseconds: 500));
        progress = 0.3;

        addLog(l10n.encryptingPayload);
        // Use compute for encryption to keep UI responsive
        final encryptedBytes =
            await compute(_encryptBytesTask, {'data': bytes, 'key': key});
        await Future.delayed(const Duration(milliseconds: 500));
        progress = 0.7;
        addLog(l10n.payloadEncrypted);

        addLog(l10n.startingServer);
        final port = await LocalServerManager.startServer(
            encryptedBytes, fileName, onDone: () {
          if (mounted) {
            setDialogState(() {
              _servingPort = 0;
              _sendingFileName = null;
            });
          }
        });
        await Future.delayed(const Duration(milliseconds: 500));
        progress = 1.0;
        addLog(l10n.serverStarted(port));

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        setDialogState(() {
          _servingPort = port;
          _sendingFileName = fileName;
        });
      } else {
        _localEncryptionKey = null;
        addLog(l10n.startingServer);
        final port =
            await LocalServerManager.startServer(bytes, fileName, onDone: () {
          if (mounted) {
            setDialogState(() {
              _servingPort = 0;
              _sendingFileName = null;
            });
          }
        });
        progress = 1.0;
        addLog(l10n.serverStarted(port));

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        setDialogState(() {
          _servingPort = port;
          _sendingFileName = fileName;
        });
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _addLog('Error starting server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: theme.colorScheme.error),
        );
      }
    } finally {
      _progressListener = null;
    }
  }

  static Uint8List _encryptBytesTask(Map<String, dynamic> params) {
    return EncryptionUtils.encryptBytes(params['data'], params['key']);
  }

  static Uint8List? _decryptBytesTask(Map<String, dynamic> params) {
    return EncryptionUtils.decryptBytes(params['data'], params['key']);
  }

  Future<void> _downloadFromLocalUrl(String url) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    List<String> progressLogs = [];
    double progressValue = 0.0;
    String speedText = '';

    void addLog(String msg) {
      progressLogs.add(msg);
      _progressListener?.call();
    }

    _elapsedTime = '00:00';
    _startStopwatch();

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setProgressState) {
            _progressListener = () {
              if (mounted) setProgressState(() {});
            };

            return AlertDialog(
              title: Text(l10n.receivingFile),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.receivingFile,
                          style: theme.textTheme.titleMedium),
                      Text(_elapsedTime,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(value: progressValue),
                  const SizedBox(height: 8),
                  if (speedText.isNotEmpty)
                    Text(l10n.downloadSpeed(speedText),
                        style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    width: double.maxFinite,
                    child: ListView.builder(
                      itemCount: progressLogs.length,
                      reverse: true,
                      itemBuilder: (context, i) => Text(
                        progressLogs[progressLogs.length - 1 - i],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final uri = Uri.parse(url);
      final key = uri.queryParameters['key'];

      addLog(l10n.connectingToServer);

      final client = http.Client();
      final request = http.Request('GET', uri);
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        final List<int> byteBuffer = [];
        final startTime = DateTime.now();

        addLog(l10n.downloadingFile(''));

        await for (final chunk in response.stream) {
          byteBuffer.addAll(chunk);
          receivedBytes += chunk.length;

          final now = DateTime.now();
          final duration = now.difference(startTime).inMilliseconds / 1000.0;
          if (duration > 0) {
            final speed = (receivedBytes / 1024.0 / 1024.0) / duration; // MB/s
            speedText = '${speed.toStringAsFixed(2)} MB/s';
          }

          if (totalBytes > 0) {
            progressValue = receivedBytes / totalBytes;
          }
          _progressListener?.call();
        }

        final bytes = Uint8List.fromList(byteBuffer);
        addLog(l10n.connectionEstablished);

        String fileName = 'downloaded_file';
        final disp = response.headers['content-disposition'];
        if (disp != null && disp.contains('filename=')) {
          fileName = disp.split('filename=').last.replaceAll('"', '');
        } else {
          fileName = p.basename(uri.path);
          if (fileName == 'download') fileName = 'securemark_file';
        }

        Uint8List finalBytes = bytes;

        if (key != null) {
          addLog(l10n.decryptingPayload);
          // Use compute for decryption
          final decrypted =
              await compute(_decryptBytesTask, {'data': bytes, 'key': key});
          if (decrypted == null) {
            throw Exception('Decryption failed. Wrong key or corrupted data.');
          }
          finalBytes = decrypted;
          progressValue = 1.0;
        }

        _stopStopwatch();
        _progressListener = null;
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        await _saveDownloadedFile(finalBytes, fileName);
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      _stopStopwatch();
      _progressListener = null;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      _addLog('Error downloading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: theme.colorScheme.error),
        );
      }
    }
  }

  Future<void> _saveDownloadedFile(Uint8List bytes, String fileName) async {
    final l10n = AppLocalizations.of(context)!;

    // Create a temporary file to use our existing saving logic
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, fileName);
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes);

    _tempFiles.add(tempPath);

    if (_outputDirectory != null) {
      final outputPath = p.join(_outputDirectory!, fileName);
      await File(outputPath).writeAsBytes(bytes);
      _addLog('Saved downloaded file to: $outputPath');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fileSaved(fileName))),
        );
      }
    } else {
      // Prompt user to save if no output dir
      final result = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
      );
      if (result != null) {
        _addLog('Saved downloaded file to: $result');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fileSaved(fileName))),
          );
        }
      }
    }
  }

  void _showIdentityQrScanner(StateSetter setParentDialogState) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scannerTitle),
        content: SizedBox(
          width: 300,
          height: 300,
          child: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  String name = 'New Identity';
                  String pubKey = code;

                  // Try to parse as JSON first (for name + key combo)
                  try {
                    final data = jsonDecode(code);
                    if (data is Map) {
                      name = data['name'] ?? 'New Identity';
                      pubKey = data['publicKey'] ?? code;
                    }
                  } catch (_) {
                    // Not JSON, assume raw public key
                  }

                  if (pubKey.length > 20) {
                    Navigator.pop(context);
                    setParentDialogState(() {
                      _identityBookmarks
                          .add(IdentityBookmark(name: name, publicKey: pubKey));
                    });
                    _saveBookmarks();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.invalidQrCode)),
                    );
                  }
                }
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _performFileAnalysis(
      Uint8List bytes, String fileName, StateSetter setDialogState) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    setDialogState(() {
      _analyzingFile = true;
      _analysisResult = null;
      _extractedSignature = null;
      _extractedFile = null;
      _verificationResult = null;
    });

    double analysisProgress = 0.0;
    String analysisMessage = l10n.processingFile;
    _elapsedTime = '00:00';
    _startStopwatch();

    // Show progress dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setProgressState) {
              _progressListener = () {
                if (mounted) {
                  setProgressState(() {});
                }
              };

              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.analyzeFile,
                            style: theme.textTheme.titleMedium),
                        Text(
                          _elapsedTime,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      analysisMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: analysisProgress,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(analysisProgress * 100).round()}%',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    // Small delay to allow dialog to render before starting heavy processing
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final password =
          _extractionPassword.isNotEmpty ? _extractionPassword : null;

      final analysis = await WatermarkProcessor.analyzeFileAsync(
        bytes,
        fileName,
        password: password,
        onProgress: (progress, messageKey) {
          analysisProgress = progress;
          // Map progress keys to localized messages
          switch (messageKey) {
            case 'progressReadingPdf':
              analysisMessage = l10n.progressReadingPdf;
              break;
            case 'progressParsingPdf':
              analysisMessage = l10n.progressParsingPdf;
              break;
            case 'progressDecodingImage':
              analysisMessage = l10n.progressDecodingImage;
              break;
            case 'progressValidating':
              analysisMessage = l10n.progressValidating;
              break;
            case 'progressVerifyingStegano':
              analysisMessage = l10n.progressVerifyingStegano;
              break;
            default:
              analysisMessage = messageKey;
          }
          _progressListener?.call();
        },
      );

      // Close progress dialog
      _stopStopwatch();
      _progressListener = null;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final results = <String>[];
      _verificationResult = analysis.verification;
      _integrityVerified = analysis.integrityVerified;
      _senderPublicKey = analysis.senderPublicKey;

      if (analysis.file != null) {
        final fileResult = analysis.file!;
        if (fileResult.isEncrypted && fileResult.fileBytes.isEmpty) {
          results.add(l10n.encryptedFileDetected(fileResult.fileName));
        } else {
          _extractedFile = fileResult;
          results.add(l10n.hiddenFileDetected(fileResult.fileName,
              _formatFileSize(fileResult.fileBytes.length)));
        }
      }

      if (analysis.signature != null && analysis.signature!.isNotEmpty) {
        final textResult = analysis.signature!;
        _extractedSignature = textResult;
        if (textResult.contains('[ENCRYPTED]')) {
          results.add(l10n.encryptedSignatureDetected);
        } else {
          results.add(l10n.signatureFound(textResult));
        }
      }

      if (analysis.robustSignature != null &&
          analysis.robustSignature!.isNotEmpty) {
        _extractedSignature = analysis.robustSignature;
        results.add(l10n.robustSignatureFound(analysis.robustSignature!));
      }

      // Handle digital integrity signature
      if (analysis.senderPublicKey != null) {
        if (analysis.integrityVerified) {
          results.add(l10n.signatureVerified);
        } else {
          results.add(l10n.tamperDetected);
        }
      }

      setDialogState(() {
        if (results.isEmpty) {
          _analysisResult = l10n.noSignatureFound;
        } else {
          _analysisResult = results.join('\n\n');
        }
      });
    } catch (e) {
      _stopStopwatch();
      _progressListener = null;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setDialogState(() {
        _analysisResult = l10n.analysisError(e.toString());
      });
    } finally {
      setDialogState(() {
        _analyzingFile = false;
      });
    }
  }

  Future<void> _performBatchAnalysis(
      Uint8List zipBytes, String fileName, StateSetter setDialogState) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    setDialogState(() {
      _analyzingFile = true;
      _analysisResult = null;
      _batchAnalysisResult = null;
      _selectedFileIndex = null;
      _extractedSignature = null;
      _extractedFile = null;
      _verificationResult = null;
    });

    double analysisProgress = 0.0;
    String analysisMessage = l10n.processingProcessing;
    _elapsedTime = '00:00';
    _startStopwatch();

    // Helper function to show progress dialog
    void showProgressDialog() {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setProgressState) {
                _progressListener = () {
                  if (mounted) {
                    setProgressState(() {});
                  }
                };

                return AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.analyzeFile,
                              style: theme.textTheme.titleMedium),
                          Text(
                            _elapsedTime,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        analysisMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: analysisProgress,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(analysisProgress * 100).round()}%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }
    }

    showProgressDialog();

    // Small delay to allow dialog to render
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      String? password =
          _extractionPassword.isNotEmpty ? _extractionPassword : null;

      // Try to extract ZIP
      Archive? archive;
      try {
        archive = ZipDecoder().decodeBytes(zipBytes, password: password);
      } catch (e) {
        // If extraction failed, prompt for password
        if (!mounted) {
          _stopStopwatch();
          _progressListener = null;
          return;
        }

        // Hide progress dialog to show password prompt
        _progressListener = null;
        Navigator.of(context, rootNavigator: true).pop();

        password = await _promptForZipPassword();
        if (password == null) {
          _stopStopwatch();
          setDialogState(() {
            _analyzingFile = false;
            _analysisResult = 'Analysis cancelled';
          });
          return;
        }

        // Show progress dialog again
        showProgressDialog();

        try {
          archive = ZipDecoder().decodeBytes(zipBytes, password: password);
        } catch (e) {
          _stopStopwatch();
          _progressListener = null;
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          setDialogState(() {
            _analyzingFile = false;
            _analysisResult = 'Wrong password';
          });
          return;
        }
      }

      // Analyze all supported files in the ZIP
      final List<FileAnalysisItem> items = [];
      final supportedExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.pdf',
        '.heic',
        '.heif'
      ];

      final relevantFiles = archive.files
          .where((f) =>
              f.isFile &&
              supportedExtensions.contains(p.extension(f.name).toLowerCase()))
          .toList();

      for (var i = 0; i < relevantFiles.length; i++) {
        final file = relevantFiles[i];
        final fileProgress = i / relevantFiles.length;

        analysisMessage =
            l10n.processingNamedFile(i + 1, relevantFiles.length, file.name);
        analysisProgress = fileProgress;
        _progressListener?.call();

        try {
          final fileBytes = file.content as List<int>;
          final analysis = await WatermarkProcessor.analyzeFileAsync(
              Uint8List.fromList(fileBytes), file.name, password: password,
              onProgress: (p, m) {
            // Update internal file progress
            analysisProgress = fileProgress + (p / relevantFiles.length);
            _progressListener?.call();
          });

          items.add(FileAnalysisItem(
            fileName: file.name,
            analysis: analysis,
          ));
        } catch (e) {
          items.add(FileAnalysisItem(
            fileName: file.name,
            analysis: null,
            error: e.toString(),
          ));
        }
      }

      // Close progress dialog
      _stopStopwatch();
      _progressListener = null;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (items.isEmpty) {
        setDialogState(() {
          _analysisResult = 'No supported files found in ZIP';
        });
      } else {
        setDialogState(() {
          _batchAnalysisResult = BatchAnalysisResult(
            items: items,
            zipPassword: password,
          );
        });
      }
    } catch (e) {
      // Close progress dialog
      _stopStopwatch();
      _progressListener = null;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setDialogState(() {
        _analysisResult = l10n.analysisError(e.toString());
      });
    } finally {
      setDialogState(() {
        _analyzingFile = false;
      });
    }
  }

  Future<String?> _promptForZipPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    String? result;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Password Required'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'ZIP Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            autofocus: true,
            onSubmitted: (value) {
              result = value;
              Navigator.of(dialogContext).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                result = controller.text;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    return result;
  }

  Widget _buildBatchAnalysisView(
      StateSetter setDialogState, ThemeData theme, AppLocalizations l10n) {
    final batch = _batchAnalysisResult!;
    final senderGroups = batch.groupBySender();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.summarize, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Batch Analysis Summary',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('Total Files', '${batch.totalFiles}',
                    Icons.insert_drive_file),
                _buildSummaryRow('Files with Signatures',
                    '${batch.filesWithSignatures}', Icons.edit_note),
                _buildSummaryRow('Files with Hidden Files',
                    '${batch.filesWithHiddenFiles}', Icons.attach_file),
                _buildSummaryRow('Files with Integrity Verified',
                    '${batch.filesWithIntegrity}', Icons.verified),
                if (batch.filesWithErrors > 0)
                  _buildSummaryRow('Files with Errors',
                      '${batch.filesWithErrors}', Icons.error,
                      color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Signed by ${senderGroups.length} sender(s)',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
                // List senders
                for (final entry in senderGroups.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '  • ${entry.key == "unsigned" ? "Unsigned" : _getSenderName(entry.key)}: ${entry.value.length} file(s)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Files list
          Text(
            'Files in Archive',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // Use Column with ExpansionTiles instead of ListView
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int index = 0; index < batch.items.length; index++) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  _buildFileListItem(
                      batch.items[index], index, setDialogState, theme, l10n),
                  // Show detail view inline if this item is selected
                  if (_selectedFileIndex == index) ...[
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildFileDetailView(
                          batch.items[index], setDialogState, theme, l10n),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileListItem(FileAnalysisItem item, int index,
      StateSetter setDialogState, ThemeData theme, AppLocalizations l10n) {
    final isSelected = _selectedFileIndex == index;

    return ListTile(
      selected: isSelected,
      selectedTileColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: Icon(
        _getFileIcon(item.fileName),
        color: item.hasError
            ? Colors.red
            : item.hasIntegrity
                ? Colors.blue
                : null,
      ),
      title: Text(
        p.basename(item.fileName),
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.hasError
            ? 'Error: ${item.error}'
            : item.hasIntegrity
                ? 'Signed & Verified'
                : item.hasSignature
                    ? 'Has signature'
                    : 'No signature',
        style: TextStyle(
          fontSize: 12,
          color: item.hasError
              ? Colors.red
              : item.hasIntegrity
                  ? Colors.blue
                  : theme.textTheme.bodySmall?.color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.hasSignature) const Icon(Icons.edit_note, size: 16),
          if (item.hasHiddenFile) const Icon(Icons.attach_file, size: 16),
          if (item.hasIntegrity)
            const Icon(Icons.verified, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Icon(
            isSelected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 20,
          ),
        ],
      ),
      onTap: () {
        setDialogState(() {
          _selectedFileIndex = isSelected ? null : index;
        });
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
      case '.heic':
      case '.heif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getSenderName(String publicKey) {
    if (publicKey == _devicePublicKey) {
      return 'Me (${_deviceName.isNotEmpty ? _deviceName : 'This Device'})';
    }
    final bookmark =
        _identityBookmarks.where((b) => b.publicKey == publicKey).firstOrNull;
    if (bookmark != null) {
      return bookmark.name;
    }
    return '${publicKey.substring(0, 8)}...${publicKey.substring(publicKey.length - 8)}';
  }

  Widget _buildFileDetailView(FileAnalysisItem item, StateSetter setDialogState,
      ThemeData theme, AppLocalizations l10n) {
    final analysis = item.analysis;
    if (analysis == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Error analyzing file',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.error ?? 'Unknown error',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }

    final results = <Widget>[];

    if (analysis.integrityVerified && analysis.senderPublicKey != null) {
      final isBookmarked = _identityBookmarks
          .any((b) => b.publicKey == analysis.senderPublicKey);
      final senderName = _getSenderName(analysis.senderPublicKey!);
      final isOwnDevice = analysis.senderPublicKey == _devicePublicKey;

      results.add(
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Digitally Signed & Verified',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'By: $senderName',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!isBookmarked && !isOwnDevice)
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  tooltip: 'Bookmark this identity',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final nameController = TextEditingController();
                    final save = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Bookmark Identity'),
                        content: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            hintText: 'e.g. John Doe',
                          ),
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );

                    if (save == true && nameController.text.isNotEmpty) {
                      setDialogState(() {
                        _identityBookmarks.add(IdentityBookmark(
                            name: nameController.text,
                            publicKey: analysis.senderPublicKey!));
                      });
                      _saveBookmarks();
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.bookmarkSaved)),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      );
    }

    if (analysis.file != null) {
      final fileResult = analysis.file!;
      results.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Icon(Icons.attach_file, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileResult.isEncrypted && fileResult.fileBytes.isEmpty
                      ? 'Encrypted file: ${fileResult.fileName}'
                      : 'Hidden file: ${fileResult.fileName} (${_formatFileSize(fileResult.fileBytes.length)})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (analysis.signature != null && analysis.signature!.isNotEmpty) {
      results.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.message, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  analysis.signature!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (analysis.robustSignature != null &&
        analysis.robustSignature!.isNotEmpty) {
      results.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Robust: ${analysis.robustSignature!}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (results.isNotEmpty)
            ...results
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No signature or hidden data found',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (analysis.file != null &&
              (!analysis.file!.isEncrypted ||
                  analysis.file!.fileBytes.isNotEmpty)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _saveExtractedFileFromBatch(analysis.file!),
                icon: const Icon(Icons.save_alt, size: 16),
                label:
                    const Text('Extract File', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveExtractedFileFromBatch(ExtractedFileResult file) async {
    final l10n = AppLocalizations.of(context)!;
    if (file.isEncrypted && file.fileBytes.isEmpty) {
      _addLog('Cannot save: file is encrypted and no password provided');
      return;
    }

    try {
      final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName: file.fileName,
      );

      if (saveLocation == null) {
        _addLog('Save cancelled by user');
        return;
      }

      final outputFile = XFile.fromData(
        file.fileBytes,
        name: file.fileName,
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _saveExtractedFile() async {
    final l10n = AppLocalizations.of(context)!;
    if (_extractedFile == null) return;

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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                              l10n.steganographyZipNote,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: _steganographyTextController,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        labelText: l10n.steganographyTextLabel,
                        hintText: l10n.steganographyTextHint,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.text_fields_rounded),
                      ),
                      onChanged: (value) {
                        _savePreference('steganographyText', value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _hidingPasswordController,
                      decoration: InputDecoration(
                        labelText: l10n.steganographyPasswordLabel,
                        hintText: l10n.steganographyPasswordHint,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureHidingPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            final newValue = !_obscureHidingPassword;
                            setDialogState(() {
                              _obscureHidingPassword = newValue;
                            });
                            setState(() {
                              _obscureHidingPassword = newValue;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureHidingPassword,
                      onChanged: (value) {
                        setState(() => _hidingPassword = value);
                        _savePreference('hidingPassword', value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Note: This password will be required to see signature and the hidden file using SecureMark. It uses AES-256 encryption.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic)),
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
                            _hiddenFileBytes = null;
                            _hiddenFileName = null;
                            _savePreference('hiddenFileBytes', null);
                            _savePreference('hiddenFileName', null);
                          }
                        });
                        setState(() {
                          _hideFileWithSteganography = enabled;
                          if (!enabled) {
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
                            color:
                                theme.colorScheme.error.withValues(alpha: 0.5),
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
                            withData: true,
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
                            _savePreference(
                                'hiddenFileName', platformFile.name);
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
                            _savePreference(
                                'hiddenFileName', platformFile.name);
                          }
                        },
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          _hiddenFileName != null && _hiddenFileName!.isNotEmpty
                              ? l10n.selectedHiddenFile(_hiddenFileName!)
                              : l10n.selectFileToHide,
                        ),
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
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

  void _showSelectedFilesModal() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.selectedFilesLabel(_selectedPaths.length),
                          style: theme.textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _selectedPaths.isEmpty
                        ? Center(child: Text(l10n.emptyPreviewHint))
                        : GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1,
                            ),
                            itemCount: _selectedPaths.length,
                            itemBuilder: (context, index) {
                              final path = _selectedPaths[index];
                              final fileName = p.basename(path);
                              final extension = p.extension(path).toLowerCase();
                              final isPdf = extension == '.pdf';

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Column(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: theme.colorScheme
                                                    .outlineVariant),
                                            color: theme.colorScheme
                                                .surfaceContainerHighest,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Center(
                                            child: isPdf
                                                ? FutureBuilder<Uint8List>(
                                                    future: () async {
                                                      final bytes =
                                                          await File(path)
                                                              .readAsBytes();
                                                      final preview =
                                                          await Printing.raster(
                                                                  bytes,
                                                                  pages: [0],
                                                                  dpi: 72)
                                                              .first;
                                                      return await preview
                                                          .toPng();
                                                    }(),
                                                    builder:
                                                        (context, snapshot) {
                                                      if (snapshot.hasData) {
                                                        return Image.memory(
                                                          snapshot.data!,
                                                          fit: BoxFit.cover,
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
                                                        );
                                                      }

                                                      return Icon(
                                                          Icons.picture_as_pdf,
                                                          size: 40,
                                                          color: theme
                                                              .colorScheme
                                                              .error);
                                                    },
                                                  )
                                                : Image.file(
                                                    File(path),
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        const Icon(
                                                            Icons.broken_image),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fileName,
                                        style: theme.textTheme.labelSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    top: -10,
                                    right: -10,
                                    child: GestureDetector(
                                      onTap: () async {
                                        setState(() {
                                          _selectedPaths.removeAt(index);
                                          if (_selectedPaths.isEmpty) {
                                            _rawImage = null;
                                            _processedFiles = <ProcessedFile>[];
                                            Navigator.pop(context);
                                          }
                                        });

                                        if (_selectedPaths.isNotEmpty &&
                                            index == 0) {
                                          await _selectPaths(
                                              List.from(_selectedPaths));
                                        }
                                        setModalState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.error,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFontOptions() {
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
                  const Icon(Icons.font_download_outlined),
                  const SizedBox(width: 12),
                  Text(l10n.fontConfigTitle),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static const Map<String, Color> _uiColorSchemes = {
    'Deep Purple (Default)': Colors.deepPurple,
    'Professional Blue': Colors.blue,
    'Security Red': Colors.red,
    'Nature Green': Colors.green,
    'Stealth Black': Colors.black,
    'High-Visibility Orange': Colors.orange,
    'Corporate Gray': Colors.blueGrey,
  };

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
                    const SizedBox(height: 16),
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
                    const Divider(),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: Text(l10n.digitallySignTitle),
                      subtitle: Text(l10n.digitallySignSubtitle),
                      value: _digitallySign,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        final bool enabled = value ?? false;
                        setDialogState(() {
                          _digitallySign = enabled;
                          // Automatically enable ZIP when digital signature is enabled
                          // to preserve integrity metadata
                          if (enabled) {
                            _zipOutputs = true;
                          }
                        });
                        setState(() {
                          _digitallySign = enabled;
                          if (enabled) {
                            _zipOutputs = true;
                          }
                        });
                        _savePreference('digitallySign', enabled);
                        if (enabled) {
                          _savePreference('zipOutputs', true);
                        }
                      },
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.folder_zip_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.secureZipTitle,
                            style: theme.textTheme.titleSmall),
                      ],
                    ),
                    CheckboxListTile(
                      title: Text(l10n.enableSecureZip),
                      value: _useSecureZip,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        final bool enabled = value ?? false;
                        setDialogState(() {
                          _useSecureZip = enabled;
                        });
                        setState(() {
                          _useSecureZip = enabled;
                        });
                        _savePreference('useSecureZip', enabled);
                      },
                    ),
                    if (_useSecureZip) ...[
                      const SizedBox(height: 8),
                      TextField(
                        obscureText: _obscureSecureZipPassword,
                        decoration: InputDecoration(
                          labelText: l10n.secureZipPasswordLabel,
                          hintText: l10n.secureZipPasswordHint,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureSecureZipPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              final newValue = !_obscureSecureZipPassword;
                              setDialogState(() {
                                _obscureSecureZipPassword = newValue;
                              });
                              setState(() {
                                _obscureSecureZipPassword = newValue;
                              });
                            },
                          ),
                        ),
                        onChanged: (value) {
                          _savePreference('secureZipPassword', value);
                        },
                        controller: _secureZipPasswordController,
                      ),
                    ],
                    /*
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.pdfSecurityTitle,
                            style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.pdfSecuritySubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                    CheckboxListTile(
                      title: Text(l10n.enablePdfSecurity),
                      value: _enablePdfSecurity,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        final bool enabled = value ?? false;
                        setDialogState(() {
                          _enablePdfSecurity = enabled;
                        });
                        setState(() {
                          _enablePdfSecurity = enabled;
                        });
                        _savePreference('enablePdfSecurity', enabled);
                      },
                    ),
                    if (_enablePdfSecurity) ...[
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          labelText: l10n.pdfUserPasswordLabel,
                          hintText: l10n.pdfUserPasswordHint,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_open_outlined),
                        ),
                        onChanged: (value) {
                          _savePreference('pdfUserPassword', value);
                        },
                        controller: _pdfUserPasswordController,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          labelText: l10n.pdfOwnerPasswordLabel,
                          hintText: l10n.pdfOwnerPasswordHint,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.enhanced_encryption),
                        ),
                        onChanged: (value) {
                          _savePreference('pdfOwnerPassword', value);
                        },
                        controller: _pdfOwnerPasswordController,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: Text(l10n.pdfAllowPrinting),
                        value: _pdfAllowPrinting,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          final bool enabled = value ?? false;
                          setDialogState(() {
                            _pdfAllowPrinting = enabled;
                          });
                          setState(() {
                            _pdfAllowPrinting = enabled;
                          });
                          _savePreference('pdfAllowPrinting', enabled);
                        },
                      ),
                      CheckboxListTile(
                        title: Text(l10n.pdfAllowCopying),
                        value: _pdfAllowCopying,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          final bool enabled = value ?? false;
                          setDialogState(() {
                            _pdfAllowCopying = enabled;
                          });
                          setState(() {
                            _pdfAllowCopying = enabled;
                          });
                          _savePreference('pdfAllowCopying', enabled);
                        },
                      ),
                      CheckboxListTile(
                        title: Text(l10n.pdfAllowEditing),
                        value: _pdfAllowEditing,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          final bool enabled = value ?? false;
                          setDialogState(() {
                            _pdfAllowEditing = enabled;
                          });
                          setState(() {
                            _pdfAllowEditing = enabled;
                          });
                          _savePreference('pdfAllowEditing', enabled);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          l10n.pdfSecurityNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                    */
                    const Divider(),
                    const SizedBox(height: 8),
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
                    const Divider(),
                    const SizedBox(height: 8),
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
                    CheckboxListTile(
                      title: Text(l10n.aiCloakingTitle),
                      subtitle: Text(l10n.aiCloakingSubtitle),
                      value: _useAiCloaking,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        final bool enabled = value ?? false;
                        setDialogState(() {
                          _useAiCloaking = enabled;
                        });
                        setState(() {
                          _useAiCloaking = enabled;
                        });
                        _savePreference('useAiCloaking', enabled);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text("UI Theme Color", style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Color>(
                          value: _uiColorSchemes.values.any((c) =>
                                  c.toARGB32() ==
                                  SecureMarkApp.of(context)
                                      .seedColor
                                      .toARGB32())
                              ? _uiColorSchemes.values.firstWhere((c) =>
                                  c.toARGB32() ==
                                  SecureMarkApp.of(context)
                                      .seedColor
                                      .toARGB32())
                              : Colors.deepPurple,
                          isExpanded: true,
                          onChanged: (Color? newValue) {
                            if (newValue != null) {
                              SecureMarkApp.of(context)
                                  .setSeedColor(newValue);
                            }
                          },
                          items: _uiColorSchemes.entries
                              .map<DropdownMenuItem<Color>>((entry) {
                            return DropdownMenuItem<Color>(
                              value: entry.value,
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: entry.value,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: theme.dividerColor),
                                    ),
                                  ),
                                  Text(entry.key),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.themeLabel,
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
                        child: DropdownButton<AppTheme>(
                          value: SecureMarkApp.of(context).appTheme,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: AppTheme.system,
                              child: Text(l10n.themeSystem),
                            ),
                            DropdownMenuItem(
                              value: AppTheme.light,
                              child: Text(l10n.themeLight),
                            ),
                            DropdownMenuItem(
                              value: AppTheme.dark,
                              child: Text(l10n.themeDark),
                            ),
                            DropdownMenuItem(
                              value: AppTheme.amoled,
                              child: Text(l10n.themeAmoled),
                            ),
                          ],
                          onChanged: (mode) {
                            if (mode != null) {
                              SecureMarkApp.of(context).setThemeMode(mode);
                              setDialogState(() {});
                            }
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
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.folder_open),
                        label: Text(l10n.selectOutputDirectory),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.logoDirectoryLabel(
                            _logoDirectory ?? l10n.resizeNone),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _pickLogoDirectory();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.folder_shared_outlined),
                        label: Text(l10n.selectLogoDirectory),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showResetProfilesModal();
                      },
                      icon: const Icon(Icons.settings_backup_restore),
                      label: Text(l10n.resetProfiles),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();

                        setDialogState(() {
                          _fontSize = 24.0;
                          _jpegQuality = 75;
                          _targetSize = 1280;
                          _includeTimestamp = true;
                          _preserveMetadata = false;
                          _rasterizePdf = false;
                          _filePrefix = 'securemark-';
                          _antiAiLevel = 50.0;
                          _useRandomColor = true;
                          _selectedColor = Colors.deepPurple;
                          _selectedFont = WatermarkFont.arial;
                          _outputDirectory = null;
                          _logoDirectory = null;
                        });

                        setState(() {
                          _fontSize = 24.0;
                          _jpegQuality = 75;
                          _targetSize = 1280;
                          _includeTimestamp = true;
                          _preserveMetadata = false;
                          _rasterizePdf = false;
                          _filePrefix = 'securemark-';
                          _antiAiLevel = 50.0;
                          _useRandomColor = true;
                          _selectedColor = Colors.deepPurple;
                          _selectedFont = WatermarkFont.arial;
                          _outputDirectory = null;
                          _logoDirectory = null;
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
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _exportConfiguration();
                            },
                            icon: const Icon(Icons.upload_file),
                            label: Text(l10n.exportConfigButton),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _importConfiguration();
                            },
                            icon: const Icon(Icons.download),
                            label: Text(l10n.importConfigButton),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: _loadingFiles
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.loadingSelectedFiles),
                ],
              ),
            )
          : _processedFiles.isEmpty
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
                              final fileName =
                                  p.basename(_selectedPaths[index]);
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
                      ] else if (_rawImage != null &&
                          _shaderProgram != null) ...[
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
                      File(_currentProcessedFile!.sourcePath)
                          .uri
                          .pathSegments
                          .last,
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
                            _transformationController.value =
                                Matrix4.identity();
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
                                  onDoubleTapDown: (details) {
                                    final currentScale =
                                        _transformationController.value
                                            .getMaxScaleOnAxis();
                                    final targetScale = currentScale <= 1.0
                                        ? 2.5
                                        : currentScale <= 2.5
                                            ? 4.0
                                            : 1.0;

                                    if (!kIsWeb &&
                                        (Platform.isAndroid ||
                                            Platform.isIOS)) {
                                      HapticFeedback.lightImpact();
                                    }

                                    if (targetScale == 1.0) {
                                      _transformationController.value =
                                          Matrix4.identity();
                                    } else {
                                      final tapPosition = details.localPosition;
                                      final newMatrix = Matrix4.identity()
                                        ..translateByDouble(tapPosition.dx,
                                            tapPosition.dy, 0, 1)
                                        ..scaleByDouble(
                                            targetScale, targetScale, 1, 1)
                                        ..translateByDouble(-tapPosition.dx,
                                            -tapPosition.dy, 0, 1);

                                      _transformationController.value =
                                          newMatrix;
                                    }
                                  },
                                  child: InteractiveViewer(
                                    transformationController:
                                        _transformationController,
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    panEnabled: true,
                                    scaleEnabled: true,
                                    constrained: true,
                                    child: Center(
                                      child: _previewMode == PreviewMode.slider
                                          ? AspectRatio(
                                              aspectRatio: (_processedFiles[index].result.width != null &&
                                                      _processedFiles[index].result.height != null &&
                                                      _processedFiles[index].result.width! > 0 &&
                                                      _processedFiles[index].result.height! > 0)
                                                  ? _processedFiles[index].result.width! /
                                                      _processedFiles[index].result.height!
                                                  : 1.0,
                                              child: Builder(builder: (sliderContext) {
                                                return LayoutBuilder(builder: (context, constraints) {
                                                  return Stack(
                                                    children: [
                                                      // B (Processed) - Bottom
                                                      Image.memory(
                                                        previewBytes,
                                                        fit: BoxFit.fill,
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                      ),
                                                      // A (Original) - Top with Clip
                                                      ClipRect(
                                                        clipper: _ComparisonClipper(
                                                            _comparisonSliderValue,
                                                            isVertical: false),
                                                        child: Image.memory(
                                                          _processedFiles[index]
                                                              .result
                                                              .originalBytes!,
                                                          fit: BoxFit.fill,
                                                          width: double.infinity,
                                                          height: double.infinity,
                                                        ),
                                                      ),
                                                      // Horizontal Line
                                                      Positioned(
                                                        top: constraints
                                                                    .maxHeight *
                                                                _comparisonSliderValue -
                                                            1,
                                                        left: 0,
                                                        right: 0,
                                                        child: Container(
                                                          height: 2,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      // Draggable Handle
                                                      Positioned(
                                                        top: constraints
                                                                    .maxHeight *
                                                                _comparisonSliderValue -
                                                            20,
                                                        left: 0,
                                                        right: 0,
                                                        child: GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .translucent,
                                                          onPanUpdate: (details) {
                                                            final RenderBox? box =
                                                                sliderContext
                                                                        .findRenderObject()
                                                                    as RenderBox?;
                                                            if (box != null &&
                                                                mounted) {
                                                              final Offset
                                                                  localOffset =
                                                                  box.globalToLocal(
                                                                      details
                                                                          .globalPosition);
                                                              setState(() {
                                                                _comparisonSliderValue =
                                                                    (localOffset
                                                                                .dy /
                                                                            box.size
                                                                                .height)
                                                                        .clamp(
                                                                            0.0,
                                                                            1.0);
                                                              });
                                                            }
                                                          },
                                                          child: Center(
                                                            child: Container(
                                                              width: 40,
                                                              height: 40,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color:
                                                                    Colors.white,
                                                                shape: BoxShape
                                                                    .circle,
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .black
                                                                        .withValues(
                                                                            alpha:
                                                                                0.3),
                                                                    blurRadius: 8,
                                                                    offset:
                                                                        const Offset(
                                                                            0, 2),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Icon(
                                                                Icons
                                                                    .swap_vert_rounded,
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                size: 24,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                });
                                              }),
                                            )
                                          : Image.memory(
                                              _previewMode ==
                                                      PreviewMode.original
                                                  ? _processedFiles[index]
                                                      .result
                                                      .originalBytes!
                                                  : (_previewMode ==
                                                              PreviewMode.heatmap &&
                                                          _processedFiles[index]
                                                                  .result
                                                                  .heatmapBytes !=
                                                              null)
                                                      ? _processedFiles[index]
                                                          .result
                                                          .heatmapBytes!
                                                      : previewBytes,
                                              fit: BoxFit.contain,
                                            ),
                                    ),
                                  ),
                                ),
                                if (_processedFiles[index]
                                        .result
                                        .originalBytes !=
                                    null)
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface
                                            .withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildPreviewToggleItem(
                                            icon: Icons.image_outlined,
                                            isSelected: _previewMode ==
                                                PreviewMode.original,
                                            onTap: () => setState(() =>
                                                _previewMode =
                                                    PreviewMode.original),
                                            theme: theme,
                                            tooltip: l10n.previewModeOriginal,
                                          ),
                                          _buildPreviewToggleItem(
                                            icon: Icons.auto_fix_high,
                                            isSelected: _previewMode ==
                                                PreviewMode.processed,
                                            onTap: () => setState(() =>
                                                _previewMode =
                                                    PreviewMode.processed),
                                            theme: theme,
                                            tooltip: l10n.previewModeProcessed,
                                          ),
                                          if (!isMobile)
                                            _buildPreviewToggleItem(
                                              icon: Icons.compare,
                                              isSelected: _previewMode ==
                                                  PreviewMode.slider,
                                              onTap: () => setState(() =>
                                                  _previewMode =
                                                      PreviewMode.slider),
                                              theme: theme,
                                              tooltip: "Slider Comparison",
                                            ),
                                          if (_processedFiles[index]
                                                  .result
                                                  .heatmapBytes !=
                                              null)
                                            _buildPreviewToggleItem(
                                              icon: Icons.contrast,
                                              isSelected: _previewMode ==
                                                  PreviewMode.heatmap,
                                              onTap: () => setState(() =>
                                                  _previewMode =
                                                      PreviewMode.heatmap),
                                              theme: theme,
                                              tooltip: l10n.previewModeHeatmap,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_processedFiles[index]
                                        .result
                                        .steganographyVerified ||
                                    _processedFiles[index]
                                        .result
                                        .robustVerified)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green
                                            .withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.2),
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
                                            ? () =>
                                                _previewController.previousPage(
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
                                        heroTag: "zoom_reset_$index",
                                        onPressed: () {
                                          if (!kIsWeb &&
                                              (Platform.isAndroid ||
                                                  Platform.isIOS)) {
                                            HapticFeedback.lightImpact();
                                          }
                                          _transformationController.value =
                                              Matrix4.identity();
                                        },
                                        backgroundColor: theme
                                            .colorScheme.surface
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
                        l10n.swipeHint(
                            _previewIndex + 1, _processedFiles.length),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
    );
  }

  String _getLocalizedVerificationMessage(
      VerificationResult result, AppLocalizations l10n) {
    switch (result.messageKey) {
      case 'verifFullIntegrity':
        return l10n.verifFullIntegrity;
      case 'verifPartialIntegrity':
        return l10n.verifPartialIntegrity;
      case 'verifTamperingDetected':
        return l10n.verifTamperingDetected;
      default:
        return '';
    }
  }

  Widget _buildForensicRow(
      {required String label,
      required bool isValid,
      required AppLocalizations l10n}) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle_outline : Icons.error_outline,
          size: 14,
          color: isValid ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green[800] : Colors.red[800],
              fontWeight: isValid ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ),
        Text(
          isValid ? l10n.forensicStatusValid : l10n.forensicStatusModified,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isValid ? Colors.green[800] : Colors.red[800],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewToggleItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: _showAboutDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Antoine Giniès',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (_appVersion.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      'v$_appVersion',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _showGuide,
            icon: Icon(
              Icons.help_outline,
              size: 16,
              color: theme.hintColor,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: AppLocalizations.of(context)!.showGuide,
          ),
        ],
      ),
    );
  }

  void _showGuide() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OnboardingPage(
          onDone: () => Navigator.of(context).pop(),
          hasCamera: widget.hasCamera,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildPrimaryActionCard() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selectedCount = _selectedPaths.length;
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

    Widget buildButton(bool isDragging) {
      if (isMobile) {
        if (!widget.hasCamera) {
          return SizedBox(
            width: double.infinity,
            child: _GradientButton(
              onTap: _pickFile,
              enabled: !_processing,
              gradientColors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.7),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isDragging ? Icons.file_upload : Icons.file_upload_outlined,
                      size: 32,
                      color: theme.colorScheme.onPrimary,
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
              ),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _GradientButton(
                    onTap: _pickFile,
                    enabled: !_processing,
                    gradientColors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDragging
                                ? Icons.file_upload
                                : Icons.file_upload_outlined,
                            size: 28,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.pickFiles,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GradientButton(
                    onTap: _takePhoto,
                    enabled: !_processing,
                    gradientColors: [
                      theme.colorScheme.secondary,
                      theme.colorScheme.secondary.withValues(alpha: 0.7),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            size: 28,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.takePhoto,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _GradientButton(
                onTap: _scanDocument,
                enabled: !_processing,
                gradientColors: [
                  theme.colorScheme.tertiary,
                  theme.colorScheme.tertiary.withValues(alpha: 0.7),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.document_scanner_outlined,
                          color: theme.colorScheme.onTertiary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.scanDocument,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return _GradientButton(
        onTap: _pickFile,
        enabled: !_processing,
        gradientColors: [
          theme.colorScheme.primary,
          theme.colorScheme.primary.withValues(alpha: 0.7),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDragging ? Icons.file_upload : Icons.file_upload_outlined,
                size: 32,
                color: theme.colorScheme.onPrimary,
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                if (paths.isNotEmpty) {
                  setState(() => _loadingFiles = true);
                  await _selectPaths(paths);
                }
              },
              child: buildButton(_dragging),
            )
          else
            buildButton(false),
          if (selectedCount > 0) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _showSelectedFilesModal,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  selectedCount == 1
                      ? l10n.selectedFile(
                          File(_selectedPaths.first).uri.pathSegments.last)
                      : l10n.selectedFiles(selectedCount),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.underline,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
    final theme = Theme.of(context);

    final bool canApply = !(_processing ||
        _selectedPaths.isEmpty ||
        (_watermarkType == WatermarkType.image &&
            _watermarkImageBytes == null));

    return Card(
      elevation: 6,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Primary "Apply SecureMark" Button
            Container(
              decoration: BoxDecoration(
                gradient: canApply
                    ? LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: canApply
                    ? null
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _PushDownWrapper(
                enabled: canApply,
                child: FilledButton.icon(
                  onPressed: canApply ? _applyWatermark : null,
                  icon: const Icon(Icons.auto_fix_high, size: 24),
                  label: Text(
                    l10n.applyWatermark,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.transparent),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return theme.colorScheme.onSurfaceVariant;
                      }
                      return Colors.white;
                    }),
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 20)),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                    elevation: WidgetStateProperty.all(0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Secondary buttons row/wrap
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (!isMobile)
                  _PushDownWrapper(
                    enabled: !_processing && _processedFiles.isNotEmpty,
                    child: FilledButton.tonalIcon(
                      onPressed: _processing || _processedFiles.isEmpty
                          ? null
                          : _saveCurrent,
                      icon: const Icon(Icons.save_alt),
                      label: Text(l10n.saveAll),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16)),
                        shape: WidgetStateProperty.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ),
                _PushDownWrapper(
                  enabled: !_processing && _processedFiles.isNotEmpty,
                  child: FilledButton.tonalIcon(
                    onPressed: _processing || _processedFiles.isEmpty
                        ? null
                        : _shareCurrent,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.shareAll),
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16)),
                      shape: WidgetStateProperty.all(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ),
                _PushDownWrapper(
                  enabled: !_processing,
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : _reset,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.reset),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return theme.colorScheme.surfaceContainerHighest;
                        }
                        return theme.colorScheme.surface;
                      }),
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16)),
                      shape: WidgetStateProperty.all(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                      side: WidgetStateProperty.all(BorderSide(
                          color: theme.colorScheme.outline, width: 1.5)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedWatermarkCard() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    const palette = <Color>[
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.white,
      Colors.black,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text | Image/Logo Picker
            Row(
              children: [
                Expanded(
                  child: _buildWatermarkTypeCard(
                    context: context,
                    type: WatermarkType.text,
                    title: l10n.watermarkTypeText,
                    icon: Icons.text_fields_rounded,
                    isSelected: _watermarkType == WatermarkType.text,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWatermarkTypeCard(
                    context: context,
                    type: WatermarkType.image,
                    title: l10n.watermarkTypeImage,
                    icon: Icons.image_rounded,
                    isSelected: _watermarkType == WatermarkType.image,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Text input OR Logo button
            if (_watermarkType == WatermarkType.text)
              TextField(
                controller: _textController,
                enabled: !_processing,
                decoration: InputDecoration(
                  labelText: l10n.watermarkTextLabel,
                  hintText: l10n.watermarkTextHint,
                  border: const OutlineInputBorder(),
                ),
              )
            else if (_supportsDesktopDrop)
              DropTarget(
                onDragEntered: (_) => setState(() => _logoDragging = true),
                onDragExited: (_) => setState(() => _logoDragging = false),
                onDragDone: (detail) async {
                  setState(() => _logoDragging = false);
                  if (detail.files.isNotEmpty) {
                    _loadLogoFromPath(detail.files.first.path);
                  }
                },
                child: _buildLogoButton(l10n, _logoDragging),
              )
            else
              _buildLogoButton(l10n, false),
            const SizedBox(height: 16),
            // Unified Color Selection
            if (_watermarkType == WatermarkType.text) ...[
              Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Random Color Rectangle
                    InkWell(
                      onTap: _processing ? null : () => _updateColorMode(true),
                      borderRadius: BorderRadius.circular(4),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _useRandomColor ? 1.0 : 0.4,
                        child: Container(
                          width: 50,
                          height: 34,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _useRandomColor
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade400,
                              width: _useRandomColor ? 1.5 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Container(color: Colors.red)),
                                    Expanded(
                                        child: Container(color: Colors.blue)),
                                    Expanded(
                                        child: Container(color: Colors.green)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Container(color: Colors.orange)),
                                    Expanded(
                                        child: Container(color: Colors.purple)),
                                    Expanded(
                                        child: Container(color: Colors.cyan)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Palette Circles
                    ...palette.map((color) {
                      final isSelected = !_useRandomColor &&
                          color.toARGB32() == _selectedColor.toARGB32();
                      return InkWell(
                        onTap: _processing
                            ? null
                            : () {
                                _updateColorMode(false);
                                _selectColor(color);
                              },
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isSelected ? 1.0 : 0.4,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade400,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(l10n.logoSizeLabel(_logoSize.round()),
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Slider(
                value: _logoSize,
                min: 30,
                max: 100,
                divisions: 70,
                label: '${_logoSize.round()}px',
                onChanged: _processing
                    ? null
                    : (value) {
                        setState(() {
                          _logoSize = value;
                        });
                      },
              ),
              const SizedBox(height: 8),
            ],
            // Graphical Visual Dashboard (Unified)
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) =>
                  _buildUnifiedVisualDashboard(constraints),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedVisualDashboard(BoxConstraints constraints) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final width = constraints.maxWidth;
    const double height = 160.0;

    // Calculate high-contrast background color
    final baseColor = _useRandomColor ? Colors.red : _selectedColor;
    final backgroundColor = _useRandomColor
        ? Colors.white
        : (baseColor.computeLuminance() > 0.5 ? Colors.black : Colors.white);

    // Map current values to 0.0-1.0 range for the UI dot position
    // x=0 (Left) should be transparency=100 (Invisible)
    // x=1 (Right) should be transparency=0 (Visible)
    final x = 1.0 - (_transparency / 100);
    final y = 1.0 - ((_density - 10) / 80); // 0 is top (90% density)

    return GestureDetector(
      onPanUpdate: (details) {
        if (_processing) return;
        final newX = (details.localPosition.dx / width).clamp(0.0, 1.0);
        final newY = (details.localPosition.dy / height).clamp(0.0, 1.0);

        setState(() {
          _transparency = (1.0 - newX) * 100;
          _density = 10 + ((1.0 - newY) * 80);
        });
        _savePreference('transparency', _transparency);
        _savePreference('density', _density);
      },
      onTapDown: (details) {
        if (_processing) return;
        final newX = (details.localPosition.dx / width).clamp(0.0, 1.0);
        final newY = (details.localPosition.dy / height).clamp(0.0, 1.0);

        setState(() {
          _transparency = (1.0 - newX) * 100;
          _density = 10 + ((1.0 - newY) * 80);
        });
        _savePreference('transparency', _transparency);
        _savePreference('density', _density);
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 1. Live Preview Layer (Density + Text)
            Positioned.fill(
              child: Opacity(
                opacity: (100 - _transparency) / 100,
                child: CustomPaint(
                  painter: _DensityPainter(
                    density: _density,
                    color: baseColor,
                    isPreview: true,
                    useRandomColor: _useRandomColor,
                  ),
                ),
              ),
            ),
            // 2. Axis Labels
            Positioned(
              bottom: 6,
              right: 8,
              child: Text('${l10n.opacityLabel} →',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: backgroundColor == Colors.black
                          ? Colors.white38
                          : Colors.black38)),
            ),
            Positioned(
              top: 8,
              left: 6,
              child: Text('↓ ${l10n.densityLabel}',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: backgroundColor == Colors.black
                          ? Colors.white38
                          : Colors.black38)),
            ),
            // 3. Interactive Cross-hair Layer
            Positioned.fill(
              child: CustomPaint(
                painter: _XYPadPainter(
                  x: x,
                  y: y,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
            // 4. The Draggable Dot
            Positioned(
              left: (x * width) - 14,
              top: (y * height) - 14,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatermarkTypeCard({
    required BuildContext context,
    required WatermarkType type,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? null : colorScheme.surface,
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.primaryContainer.withValues(alpha: 0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _processing
              ? null
              : () {
                  setState(() {
                    _watermarkType = type;
                  });
                },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoButton(AppLocalizations l10n, bool isDragging) {
    final theme = Theme.of(context);
    return ElevatedButton.icon(
      onPressed: _processing ? null : _selectWatermarkImage,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: Text(
        _watermarkImageName != null
            ? l10n.selectedWatermarkImage(_watermarkImageName!)
            : l10n.selectWatermarkImage,
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: isDragging ? theme.colorScheme.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isDragging
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
      ),
    );
  }

  /// Builds the complete list of toggleable watermark options
  List<WatermarkOption> _buildAllOptions(AppLocalizations l10n) {
    return [
      // Digital Signature
      WatermarkOption(
        id: 'digital_sign',
        label: l10n.digitallySignTitle,
        icon: Icons.fingerprint,
        enabledColor: Colors.blueAccent,
        isEnabled: _digitallySign,
        isAvailable: !_rasterizePdf,
        unavailableReason: _rasterizePdf ? l10n.unavailableRasterPdf : null,
        subtitle: _digitallySign ? 'Integrity protection enabled' : null,
        onToggle: () {
          if (!_rasterizePdf) {
            setState(() {
              _digitallySign = !_digitallySign;
              if (_digitallySign) {
                _zipOutputs = true; // Auto-enable zip for signing
              }
            });
            _savePreference('digitallySign', _digitallySign);
            if (_digitallySign) {
              _savePreference('zipOutputs', true);
            }
          }
        },
        onConfigure: _showExpertOptions,
      ),

      // Steganography
      WatermarkOption(
        id: 'steganography',
        label: l10n.steganographyTitle,
        icon: Icons.verified_user_outlined,
        enabledColor: Colors.green,
        isEnabled: _useSteganography,
        isAvailable: !_rasterizePdf,
        unavailableReason: _rasterizePdf ? l10n.unavailableRasterPdf : null,
        subtitle: _useSteganography ? l10n.steganographyEnabledHint : null,
        onToggle: () {
          if (!_rasterizePdf) {
            setState(() {
              _useSteganography = !_useSteganography;
              // If disabling steganography, also disable dependent features
              if (!_useSteganography) {
                if (_useRobustSteganography) {
                  _useRobustSteganography = false;
                  _savePreference('useRobustSteganography', false);
                }
                if (_hideFileWithSteganography) {
                  _hideFileWithSteganography = false;
                  _savePreference('hideFileWithSteganography', false);
                }
              }
            });
            _savePreference('useSteganography', _useSteganography);
          }
        },
        onConfigure: _showSteganographyOptions,
      ),

      // Robust Steganography
      WatermarkOption(
        id: 'robust_stego',
        label: l10n.robustSteganographyTitle,
        icon: Icons.shield_outlined,
        enabledColor: Colors.indigo,
        isEnabled: _useRobustSteganography,
        isAvailable: _useSteganography && !_rasterizePdf,
        unavailableReason: _rasterizePdf
            ? l10n.unavailableRasterPdf
            : (_useSteganography ? null : l10n.requiresSteganography),
        onToggle: () {
          if (_useSteganography && !_rasterizePdf) {
            setState(() {
              _useRobustSteganography = !_useRobustSteganography;
            });
            _savePreference('useRobustSteganography', _useRobustSteganography);
          }
        },
        onConfigure: _showSteganographyOptions,
      ),

      // AI Cloaking
      WatermarkOption(
        id: 'ai_cloaking',
        label: l10n.aiCloakingTitle,
        icon: Icons.visibility_off_outlined,
        enabledColor: Colors.teal,
        isEnabled: _useAiCloaking,
        subtitle: _useAiCloaking ? l10n.aiCloakingEnabledHint : null,
        onToggle: () {
          setState(() {
            _useAiCloaking = !_useAiCloaking;
          });
          _savePreference('useAiCloaking', _useAiCloaking);
        },
        onConfigure: _showExpertOptions,
      ),

      // QR Code Watermark
      WatermarkOption(
        id: 'qr_watermark',
        label: l10n.qrWatermarkTitle,
        icon: Icons.qr_code_2,
        enabledColor: Colors.blue,
        isEnabled: _qrVisible,
        subtitle: _qrVisible && _qrType != QrType.metadata
            ? 'Type: ${_qrType.name.toUpperCase()}'
            : null,
        onToggle: () {
          setState(() {
            _qrVisible = !_qrVisible;
          });
          _savePreference('qrVisible', _qrVisible);
        },
        onConfigure: _showQrWatermarkOptions,
      ),

      // Hide File (Steganography)
      WatermarkOption(
        id: 'hide_file',
        label: 'Hide File',
        icon: Icons.attachment,
        enabledColor: Colors.brown,
        isEnabled: _hideFileWithSteganography && _hiddenFileBytes != null,
        isAvailable: _useSteganography && !_rasterizePdf,
        unavailableReason: _rasterizePdf
            ? l10n.unavailableRasterPdf
            : (_useSteganography ? null : l10n.requiresSteganography),
        subtitle: _hiddenFileBytes != null ? l10n.hideFileEnabledHint : null,
        onToggle: () {
          if (_useSteganography && !_rasterizePdf) {
            // If no file is selected, open the steganography modal to select one
            if (_hiddenFileBytes == null) {
              _showSteganographyOptions();
            } else {
              setState(() {
                _hideFileWithSteganography = !_hideFileWithSteganography;
              });
              _savePreference(
                  'hideFileWithSteganography', _hideFileWithSteganography);
            }
          }
        },
        onConfigure: _showSteganographyOptions,
      ),

      // ZIP Outputs
      WatermarkOption(
        id: 'zip_outputs',
        label: l10n.zipAllFiles,
        icon: Icons.folder_zip,
        enabledColor: Colors.amber,
        isEnabled: _zipOutputs,
        isAvailable: !_digitallySign, // Disabled if signing (auto-required)
        unavailableReason: _digitallySign ? 'Required for signing' : null,
        subtitle: _zipOutputs ? l10n.zipEnabledHint : null,
        onToggle: () {
          if (!_digitallySign) {
            setState(() {
              _zipOutputs = !_zipOutputs;
            });
            _savePreference('zipOutputs', _zipOutputs);
          }
        },
        onConfigure: null, // No settings dialog
      ),

      // Anti-AI Protection
      WatermarkOption(
        id: 'anti_ai',
        label: 'Anti-AI Protection',
        icon: Icons.auto_awesome,
        enabledColor: Colors.purple,
        isEnabled: _antiAiLevel > 0,
        subtitle: _antiAiLevel > 0
            ? l10n.antiAiProtectionValue(_antiAiLevel.round())
            : null,
        onToggle: () {
          setState(() {
            _antiAiLevel = _antiAiLevel > 0 ? 0 : 50.0;
          });
          _savePreference('antiAiLevel', _antiAiLevel);
        },
        onConfigure: _showExpertOptions,
      ),

      // PDF Rasterization
      WatermarkOption(
        id: 'rasterize_pdf',
        label: l10n.rasterizePdfTitle,
        icon: Icons.picture_as_pdf,
        enabledColor: Colors.redAccent,
        isEnabled: _rasterizePdf,
        subtitle: _rasterizePdf ? l10n.rasterizePdfEnabledHint : null,
        onToggle: () {
          setState(() {
            _rasterizePdf = !_rasterizePdf;
            if (_rasterizePdf) {
              // Disable incompatible features
              _digitallySign = false;
              _useSteganography = false;
              _useRobustSteganography = false;
              _hideFileWithSteganography = false;
            }
          });
          _savePreference('rasterizePdf', _rasterizePdf);
          if (_rasterizePdf) {
            _savePreference('digitallySign', false);
            _savePreference('useSteganography', false);
            _savePreference('useRobustSteganography', false);
            _savePreference('hideFileWithSteganography', false);
          }
        },
        onConfigure: _showExpertOptions,
      ),

      // Preserve Metadata
      WatermarkOption(
        id: 'preserve_metadata',
        label: l10n.preserveMetadata,
        icon: Icons.info_outline,
        enabledColor: Colors.lightBlue,
        isEnabled: _preserveMetadata,
        subtitle: _preserveMetadata ? l10n.preserveMetadataEnabledHint : null,
        onToggle: () {
          setState(() {
            _preserveMetadata = !_preserveMetadata;
          });
          _savePreference('preserveMetadata', _preserveMetadata);
        },
        onConfigure: _showExpertOptions,
      ),

      // Image Resizing
      WatermarkOption(
        id: 'resize_image',
        label: 'Image Resizing',
        icon: Icons.photo_size_select_large,
        enabledColor: Colors.orange,
        isEnabled: _targetSize != null,
        subtitle: _targetSize != null
            ? l10n.imageResizingLabel(l10n.pixelUnit(_targetSize!))
            : null,
        onToggle: () {
          setState(() {
            _targetSize = _targetSize == null ? 1280 : null;
          });
          _savePreference('targetSize', _targetSize);
        },
        onConfigure: _showExpertOptions,
      ),

      // File Prefix (Info only)
      WatermarkOption(
        id: 'file_prefix',
        label: l10n.filePrefixLabel,
        icon: Icons.label_outline,
        enabledColor: Colors.blueGrey,
        isEnabled: true,
        subtitle: _filePrefix,
        onToggle: null, // No toggle - info only
        onConfigure: null, // No configure - info only
      ),
    ];
  }

  Widget? _buildStatusIcons(AppLocalizations l10n) {
    final allOptions = _buildAllOptions(l10n);

    // Check if we need to show verification failed warning
    final bool currentIsPdf = _processedFiles.isNotEmpty &&
        _previewIndex < _processedFiles.length &&
        _processedFiles[_previewIndex].result.isPdf;
    final showVerificationWarning =
        _steganographyVerificationFailed && !currentIsPdf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact toggle grid (4 icons per row)
        OptionToggleGrid(
          options: allOptions,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          iconSize: 44,
          spacing: 6,
        ),
        // Verification failed warning (if applicable)
        if (showVerificationWarning)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_outlined,
                    color: Colors.red.shade700, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.steganographyVerificationFailed,
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _takePhoto() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        requestFullMetadata: true,
      );

      if (photo == null) {
        _addLog('Camera capture cancelled.');
        return;
      }

      _addLog('Captured photo from camera: ${photo.path}');
      setState(() => _loadingFiles = true);
      await _selectPaths([photo.path]);
    } catch (e) {
      _addLog('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorPrefix(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _scanDocument() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
        // Fallback to standard camera for non-mobile platforms
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: true,
        );

        if (photo == null) {
          _addLog('Camera capture cancelled.');
          return;
        }

        _addLog('Captured photo from camera: ${photo.path}');
        setState(() => _loadingFiles = true);
        await _selectPaths([photo.path]);
        return;
      }

      // Use document scanner on mobile
      try {
        final List<String>? images = await CunningDocumentScanner.getPictures();

        if (images == null || images.isEmpty) {
          _addLog('Document scanning cancelled.');
          return;
        }

        _addLog('Scanned ${images.length} document(s)');
        setState(() => _loadingFiles = true);
        await _selectPaths(images);
      } catch (e) {
        _addLog(
            'Document scanner unavailable or failed: $e. Falling back to classical camera.');
        // Automatic fallback to standard photo
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: true,
        );

        if (photo == null) return;

        _addLog('Captured photo via fallback: ${photo.path}');
        setState(() => _loadingFiles = true);
        await _selectPaths([photo.path]);
      }
    } catch (e) {
      _addLog('Error scanning document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorPrefix(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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
        withData: false,
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
        setState(() => _loadingFiles = true);
        await _selectPaths(validPaths);
      } else {
        _addLog('Error: Picked files have no valid local paths.');
      }
    } catch (e) {
      _addLog('Error picking files: $e');
    }
  }

  Future<void> _selectPaths(List<String> paths) async {
    final uniquePaths = paths.toSet().toList();

    // Append new paths to existing ones instead of replacing
    final allPaths = {..._selectedPaths, ...uniquePaths}.toList();

    // If no output directory is set, use the directory from the last picked file
    if (_outputDirectory == null && allPaths.isNotEmpty) {
      final lastPath = allPaths.last;
      final directory = p.dirname(lastPath);
      setState(() {
        _outputDirectory = directory;
      });
      _savePreference('outputDirectory', directory);
      _addLog('Auto-set output directory to: $directory');
    }

    setState(() {
      _selectedPaths = allPaths;
      _processedFiles = <ProcessedFile>[];
      _previewIndex = 0;
      _rawImage = null;
      _statusMessage = '';
    });

    try {
      if (allPaths.isNotEmpty) {
        final firstPath = allPaths.first;
        final extension = p.extension(firstPath).toLowerCase();
        if (['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
          final bytes = await File(firstPath).readAsBytes();
          final completer = Completer<ui.Image>();
          ui.decodeImageFromList(bytes, (image) {
            completer.complete(image);
          });
          final image = await completer.future;
          if (mounted) {
            setState(() {
              _rawImage = image;
            });
          }
        }
      }
    } catch (e) {
      _addLog('Error reading first image for preview: $e');
      debugPrint('Preview error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingFiles = false;
        });
      }
    }
  }

  Future<void> _processPaths(List<String> paths) async {
    if (_processing || paths.isEmpty) return;

    WatermarkProcessor.clearCache();

    _addLog('Processing ${paths.length} paths');
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    _cancellationToken = CancellationToken();
    _startStopwatch();

    setState(() {
      _processing = true;
      _processedFiles = <ProcessedFile>[];
      _previewIndex = 0;
      _progress = 0.0;
      _progressMessage = '';
      _elapsedTime = '00:00';
      _statusMessage = l10n.processingCount(paths.length);
    });

    await _cleanupTempFiles();

    if (!mounted) return;

    final processedFiles = <ProcessedFile>[];
    final failedFiles = <String>[];
    final processingErrors = <String, String>{};
    bool dialogOpened = false;

    String translateProgress(String msg) {
      if (msg.startsWith('progress')) {
        if (msg.contains(':')) {
          final parts = msg.split(':');
          final key = parts[0];
          final params = parts[1].split('/');
          if (key == 'progressWatermarkingPage' && params.length == 2) {
            return l10n.progressWatermarkingPage(
                int.parse(params[0]), int.parse(params[1]));
          }
        }

        switch (msg) {
          case 'progressValidating':
            return l10n.progressValidating;
          case 'progressFromCache':
            return l10n.progressFromCache;
          case 'progressDetectingType':
            return l10n.progressDetectingType;
          case 'progressStarting':
            return l10n.progressStarting;
          case 'progressComplete':
            return l10n.progressComplete;
          case 'progressReadingImage':
            return l10n.progressReadingImage;
          case 'progressRenderingFont':
            return l10n.progressRenderingFont;
          case 'progressFinalizingImage':
            return l10n.progressFinalizingImage;
          case 'progressVerifyingStegano':
            return l10n.progressVerifyingStegano;
          case 'progressSteganoVerified':
            return l10n.progressSteganoVerified;
          case 'progressSteganoFailed':
            return l10n.progressSteganoFailed;
          case 'progressRasterizing':
            return l10n.progressRasterizing;
          case 'progressReadingPdf':
            return l10n.progressReadingPdf;
          case 'progressAddingLayer':
            return l10n.progressAddingLayer;
          case 'progressFinalizingPdf':
            return l10n.progressFinalizingPdf;
          case 'progressParsingPdf':
            return l10n.progressParsingPdf;
          case 'progressDecodingImage':
            return l10n.progressDecodingImage;
          case 'progressResizingImage':
            return l10n.progressResizingImage;
          case 'progressApplyingCloaking':
            return l10n.progressApplyingCloaking;
          case 'progressApplyingWatermark':
            return l10n.progressApplyingWatermark;
          case 'progressEmbeddingRobust':
            return l10n.progressEmbeddingRobust;
          case 'progressHidingFile':
            return l10n.progressHidingFile;
          case 'progressEmbeddingLsb':
            return l10n.progressEmbeddingLsb;
          case 'progressEncodingImage':
            return l10n.progressEncodingImage;
          case 'progressGeneratingQr':
            return l10n.progressGeneratingQr;
          case 'progressEmbeddingQr':
            return l10n.progressEmbeddingQr;
          case 'progressQrEmbedded':
            return l10n.progressQrEmbedded;
        }
      }
      return msg;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        dialogOpened = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _progressListener = () {
              if (context.mounted) {
                setDialogState(() {});
              }
            };

            final message = _progressMessage.isEmpty
                ? (_statusMessage.isEmpty
                    ? l10n.processingFile
                    : _statusMessage)
                : translateProgress(_progressMessage);

            final hasError = !_processing && failedFiles.isNotEmpty;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  if (hasError)
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: theme.colorScheme.error,
                    )
                  else
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
                  Text(
                      !_processing && failedFiles.isEmpty
                          ? l10n.processingComplete
                          : l10n.applyingWatermark,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_progress > 0 && !hasError) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).round()}${[
                        'fr',
                        'de'
                      ].contains(Localizations.localeOf(context).languageCode) ? ' %' : '%'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: (!_processing)
                        ? () {
                            _progressListener = null;
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                        : _cancelProcessing,
                    child: Text((!_processing) ? l10n.close : l10n.cancel),
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

        final bool shouldApplyStegano = _useSteganography ||
            (_hideFileWithSteganography && _hiddenFileBytes != null);

        _addLog(
            'Processing with: useSteganography=$shouldApplyStegano, hideFile=$_hideFileWithSteganography, hiddenFile=$_hiddenFileName (${_hiddenFileBytes?.length ?? 0} bytes), digitallySign=$_digitallySign');

        try {
          final result = await WatermarkProcessor.processFile(
            file: File(path),
            transparency: _transparency,
            density: _density,
            watermarkText: _textController.text,
            useRandomColor: _useRandomColor,
            selectedColorValue: _selectedColor.toARGB32(),
            fontSize:
                _watermarkType == WatermarkType.text ? _fontSize : _logoSize,
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
            useAiCloaking: _useAiCloaking,
            digitallySign: _digitallySign,
            watermarkType: _watermarkType,
            watermarkImageBytes: _watermarkImageBytes,
            steganographyPassword: _hidingPassword,
            steganographyText: _steganographyTextController.text,
            hiddenFileName: _hideFileWithSteganography ? _hiddenFileName : null,
            hiddenFileBytes:
                _hideFileWithSteganography ? _hiddenFileBytes : null,
            qrConfig: qrConfig,
            enablePdfSecurity: _enablePdfSecurity,
            pdfUserPassword: _pdfUserPasswordController.text,
            pdfOwnerPassword: _pdfOwnerPasswordController.text,
            pdfAllowPrinting: _pdfAllowPrinting,
            pdfAllowCopying: _pdfAllowCopying,
            pdfAllowEditing: _pdfAllowEditing,
            onProgress: (progress, message) {
              if (mounted) {
                if (progress < 0) {
                  _addLog(message);
                  return;
                }
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

          _addLog(
              'Successfully processed $fileName (${i + 1}/${paths.length})');
          processedFiles.add(ProcessedFile(sourcePath: path, result: result));
          _addLog('Total files processed so far: ${processedFiles.length}');
        } on WatermarkError catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.getLocalizedMessage(l10n)),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
          _cancelProcessing();
          return;
        } catch (e) {
          _addLog('Failed to process $fileName (${i + 1}/${paths.length}): $e');
          failedFiles.add(path);
          _addLog('Total files failed so far: ${failedFiles.length}');

          if (mounted) {
            String errorMessage;
            if (e is WatermarkError &&
                e.message.contains('too large to hide')) {
              final match = RegExp(
                      r'File "([^"]+)" \(([0-9.]+) KB\) is too large to hide in this image \(([^)]+)\)\. Maximum capacity: ([0-9.]+) KB')
                  .firstMatch(e.message);
              if (match != null) {
                final extractedFileName = match.group(1) ?? '';
                final fileSize = match.group(2) ?? '';
                final imageDimensions = match.group(3) ?? '';
                final maxCapacity = match.group(4) ?? '';
                errorMessage = l10n.fileTooLargeMessage(
                  extractedFileName,
                  fileSize,
                  imageDimensions,
                  maxCapacity,
                );
              } else {
                errorMessage = e.getLocalizedMessage(l10n);
              }
            } else {
              errorMessage = e is WatermarkError
                  ? e.getLocalizedMessage(l10n)
                  : l10n.errorPrefix(e.toString());
            }

            processingErrors[path] = errorMessage;

            setState(() {
              _statusMessage = errorMessage;
            });
            _progressListener?.call();
          }
        }
      }

      _addLog(
          'Processing loop complete: ${processedFiles.length} succeeded, ${failedFiles.length} failed out of ${paths.length} total');
    } finally {
      _stopStopwatch();
      if (mounted && dialogOpened) {
        Navigator.of(context, rootNavigator: true).pop();
        _progressListener = null;
      }

      if (mounted) {
        if (_cancellationToken?.isCancelled == true) {
          setState(() {
            _processing = false;
            _progress = 0.0;
            _progressMessage = '';
            _statusMessage = l10n.processingCancelled;
          });
        } else {
          if (processingErrors.isNotEmpty) {
            _showProcessingErrorsDialog(processingErrors);
          }

          final verifiedCount = processedFiles
              .where((f) =>
                  f.result.steganographyVerified || f.result.robustVerified)
              .length;

          // Only count as failed if we actually attempted it on at least one image
          final attemptedCount = processedFiles
              .where((f) =>
                  !f.result.isPdf &&
                  (_useSteganography || _useRobustSteganography))
              .length;

          final steganographyFailed = attemptedCount > 0 && verifiedCount == 0;

          if (attemptedCount > 0 && verifiedCount > 0) {
            _addLog('Steganography verified for $verifiedCount file(s)');
          } else if (attemptedCount > 0) {
            _addLog('Steganography verification failed for all files');
          }

          var successMessage = processedFiles.isEmpty
              ? l10n.processingFailed
              : failedFiles.isEmpty
                  ? ''
                  : l10n.processingStatusMultiple(
                      processedFiles.length, failedFiles.length);

          if ((_useSteganography || _useRobustSteganography) &&
              verifiedCount > 0) {
            successMessage += ' (Steganography Verified ✓)';
          }

          setState(() {
            _processedFiles = processedFiles;
            _previewIndex = 0;
            // Preserve detailed error messages (resolution limits, capacity errors, etc.)
            // Only update status if it's empty, multiline, or not a detailed error
            final hasDetailedError = _statusMessage.contains('exceeds') ||
                _statusMessage.contains('too large to hide') ||
                _statusMessage.contains('resolution') ||
                _statusMessage.contains('Maximum capacity') ||
                _statusMessage.contains('Samsung') ||
                _statusMessage.contains('TIFF-wrapped');

            if (_statusMessage.isEmpty ||
                (_statusMessage.contains('\n') && !hasDetailedError)) {
              _statusMessage = successMessage;
            }
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
    _steganographyTextController.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      _addLog('Error clearing preferences: $e');
    }

    WatermarkProcessor.clearCache();
    await _cleanupTempFiles();

    if (_previewController.hasClients) {
      _previewController.jumpToPage(0);
    }
    setState(() {
      _dragging = false;
      _logoDragging = false;
      _processing = false;
      _progress = 0.0;
      _progressMessage = '';
      _elapsedTime = '00:00';
      _transparency = 75;
      _density = 35;
      _selectedPaths = <String>[];
      _processedFiles = <ProcessedFile>[];
      _previewIndex = 0;
      _previewMode = PreviewMode.processed;
      _comparisonSliderValue = 0.5;
      _verificationResult = null;      _extractedSignature = null;
      _statusMessage = '';
      _cancellationToken = null;
      _rawImage = null;

      _fontSize = 24.0;
      _logoSize = 100.0;
      _jpegQuality = 75;
      _targetSize = 1280;
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
      _watermarkType = WatermarkType.text;
      _watermarkImageBytes = null;
      _watermarkImageName = null;
      _outputDirectory = null;
      _logoDirectory = null;
    });
  }

  Future<void> _selectWatermarkImage() async {
    _addLog(
        'Picking watermark image. Initial directory: ${_logoDirectory ?? "not set"}');
    try {
      if (!kIsWeb &&
          (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
        const XTypeGroup typeGroup = XTypeGroup(
          label: 'images',
          extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
        );
        final XFile? file = await openFile(
          acceptedTypeGroups: const <XTypeGroup>[typeGroup],
          initialDirectory: _logoDirectory,
        );

        if (file != null) {
          final Uint8List bytes = await file.readAsBytes();
          setState(() {
            _watermarkImageBytes = bytes;
            _watermarkImageName = file.name;
            _logoDirectory = p.dirname(file.path);
          });
          _savePreference('logoDirectory', _logoDirectory!);
          _addLog('Watermark image selected: ${file.name}');
          _addLog('Logo directory updated to: $_logoDirectory');
        }
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
        initialDirectory: _logoDirectory,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _watermarkImageBytes = file.bytes;
          _watermarkImageName = file.name;
          if (file.path != null) {
            _logoDirectory = p.dirname(file.path!);
          }
        });
        if (_logoDirectory != null) {
          _savePreference('logoDirectory', _logoDirectory!);
        }
        _addLog('Watermark image selected: ${file.name}');
      }
    } catch (e) {
      _addLog('Error picking watermark image: $e');
    }
  }

  Future<void> _loadLogoFromPath(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      setState(() {
        _watermarkImageBytes = bytes;
        _watermarkImageName = p.basename(path);
      });
      _addLog('Watermark image loaded from drop: ${p.basename(path)}');
    } catch (e) {
      _addLog('Error loading dropped logo: $e');
    }
  }

  /// Validates that QR code has required content based on selected type
  bool _isQrContentValid() {
    switch (_qrType) {
      case QrType.metadata:
        // Metadata type is always valid (at minimum includes timestamp and app info)
        return true;
      case QrType.url:
        // URL type requires a non-empty URL
        return _qrUrl.isNotEmpty && Uri.tryParse(_qrUrl)?.hasScheme == true;
      case QrType.vcard:
        // vCard type requires at least first name or last name
        return _vCardFirstName.isNotEmpty || _vCardLastName.isNotEmpty;
    }
  }

  Future<void> _applyWatermark() async {
    if (_selectedPaths.isEmpty) {
      return;
    }

    // Validate QR code content if QR is enabled
    if (_qrVisible && !_isQrContentValid()) {
      _showQrWatermarkOptions();
      return;
    }

    setState(() {
      _processedFiles = <ProcessedFile>[];
      _previewIndex = 0;
      _previewMode = PreviewMode.processed;
      _transformationController.value = Matrix4.identity();
      _steganographyVerificationFailed = false;
    });

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
      if (_zipOutputs) {
        try {
          final zipPath =
              await _createZipFromProcessedFiles(_processedFiles, false);
          savedFiles.add(zipPath);
        } catch (e) {
          _addLog('Failed to save ZIP: $e');
          // In case of general failure, we might not have a specific source file to report
          failedFiles.add('ZIP Archive');
        }
      } else {
        for (final file in _processedFiles) {
          try {
            String outputPath = file.result.outputPath;

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
            final logPath =
                _outputDirectory ?? p.dirname(file.result.outputPath);
            _addLog('Failed to save to $logPath: $e');
          }
        }
      }

      if (!mounted) {
        return;
      }

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

  String _getSaveLocationInfo() {
    final l10n = AppLocalizations.of(context)!;
    if (_processedFiles.isEmpty) return '';

    final firstFile = _processedFiles.first;
    final directory = _outputDirectory ?? p.dirname(firstFile.sourcePath);
    final displayDir =
        _outputDirectory != null ? _outputDirectory! : p.basename(directory);

    final displayPath = displayDir.length > 40
        ? '...${displayDir.substring(displayDir.length - 37)}'
        : displayDir;

    if (_zipOutputs) {
      return l10n.willSaveAsIn(
          'securemark-files-YYYYMMDD_HHMM.zip', displayPath);
    }

    if (_processedFiles.length == 1) {
      final fileName = p.basenameWithoutExtension(firstFile.result.outputPath);
      return l10n.willSaveAsIn(fileName, displayPath);
    } else {
      return l10n.willSaveMultipleIn(_processedFiles.length, displayPath);
    }
  }

  String _getDisplayPath(String fullPath) {
    if (fullPath.length > 50) {
      final fileName = p.basename(fullPath);
      final directory = p.basename(p.dirname(fullPath));
      return '.../$directory/$fileName';
    }
    return fullPath;
  }

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

  void _showProcessingErrorsDialog(Map<String, String> errors) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(l10n.processingErrorsTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.basename(entry.key),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade700,
                          ),
                    ),
                  ],
                ),
              );
            }).toList(),
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

  Future<String> _createZipFromProcessedFiles(
      List<ProcessedFile> processedFiles, bool useTemporaryDir) async {
    final now = DateTime.now();
    final timestamp =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
    final fileName = 'securemark-files-$timestamp.zip';

    String zipPath;
    if (useTemporaryDir) {
      final tempDir = await getTemporaryDirectory();
      zipPath = p.join(tempDir.path, fileName);
    } else {
      final firstFile = processedFiles.first;
      final directory = _outputDirectory ?? p.dirname(firstFile.sourcePath);
      zipPath = p.join(directory, fileName);
    }

    final String? zipPassword =
        _useSecureZip && _secureZipPasswordController.text.isNotEmpty
            ? _secureZipPasswordController.text
            : null;

    final encoder = ZipFileEncoder(password: zipPassword);
    encoder.create(zipPath);

    for (final file in processedFiles) {
      final fileName = p.basename(file.result.outputPath);
      final archiveFile = ArchiveFile(
        fileName,
        file.result.outputBytes.length,
        file.result.outputBytes,
      );
      encoder.addArchiveFile(archiveFile);
    }

    encoder.close();
    return zipPath;
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
      final zipPath = await _createZipFromProcessedFiles(_processedFiles, true);
      _tempFiles.add(zipPath);
      shareFiles.add(XFile(zipPath, mimeType: 'application/zip'));
    } else {
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

    if (useRandomColor) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.randomColorSelected),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  void _selectColor(Color color) {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _selectedColor = color;
    });
    _savePreference('selectedColor', color.toARGB32());

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.uniqueColorSelected),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  List<DropdownMenuItem<WatermarkFont>> _buildFontDropdownItems() {
    final items = <DropdownMenuItem<WatermarkFont>>[];

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

    final assetFonts = FontManager.assetFonts;
    if (assetFonts.isNotEmpty) {
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

    return items;
  }

  String _getFontSourceDescription(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_selectedFont.source) {
      case FontSource.bitmap:
        return l10n.fontSelectionNote;
      case FontSource.asset:
        return l10n.fontSelectionNoteAsset;
    }
  }

  void _showResetProfilesModal() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.resetProfiles),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: SettingsProfile.values.map((profile) {
              String label = '';
              IconData icon;
              switch (profile) {
                case SettingsProfile.none:
                  label = l10n.profileNone;
                  icon = Icons.not_interested;
                case SettingsProfile.secureIdentity:
                  label = l10n.profileSecureIdentity;
                  icon = Icons.fingerprint;
                case SettingsProfile.onlineImage:
                  label = l10n.profileOnlineImage;
                  icon = Icons.public;
                case SettingsProfile.qrCode:
                  label = l10n.profileQrCode;
                  icon = Icons.qr_code;
                case SettingsProfile.shareDocument:
                  label = l10n.profileShareDocument;
                  icon = Icons.description;
                case SettingsProfile.p1:
                  label = "P1";
                  icon = Icons.person_outline;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (confirmContext) => AlertDialog(
                        title: Text(l10n.resetProfiles),
                        content: Text(l10n.resetProfileConfirm(label)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmContext),
                            child: Text(l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () {
                              _resetProfileToDefaults(profile);
                              Navigator.pop(confirmContext);
                            },
                            child: Text(l10n.reset),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(icon),
                  label: Text(label),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportConfiguration() async {
    final l10n = AppLocalizations.of(context)!;
    final passwordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exportConfigTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.exportConfigDesc),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Encryption Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.exportConfigButton),
          ),
        ],
      ),
    );

    if (proceed != true || passwordController.text.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final Map<String, dynamic> configData = {};

      for (final key in allKeys) {
        // Only export SecureMark related keys
        if (key.startsWith('profile_') ||
            key.startsWith('device_') ||
            [
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
              'identity_bookmarks'
            ].contains(key)) {
          configData[key] = prefs.get(key);
        }
      }

      final jsonConfig = jsonEncode(configData);
      final jsonBytes = utf8.encode(jsonConfig);
      _addLog('Exporting configuration with ${configData.length} keys...');

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final timestamp =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final String versionSuffix =
          _appVersion.isNotEmpty ? "_v$_appVersion" : "";
      final zipPath = p.join(
          tempDir.path, 'SecureMark_Backup${versionSuffix}_$timestamp.zip');

      final encoder = ZipFileEncoder(password: passwordController.text);
      encoder.create(zipPath);
      encoder.addArchiveFile(ArchiveFile(
        'securemark_config.json',
        jsonBytes.length,
        jsonBytes,
      ));
      encoder.close();

      final bool isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

      if (isMobile) {
        // Share the file on mobile
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(zipPath, mimeType: 'application/zip')],
            subject: l10n.exportConfigTitle,
          ),
        );
        _tempFiles.add(zipPath);
      } else {
        // Manual save on Desktop/Web
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: l10n.exportConfigTitle,
          fileName: p.basename(zipPath),
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (savePath != null) {
          final bytes = await File(zipPath).readAsBytes();
          await File(savePath).writeAsBytes(bytes);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.configExportSuccess(savePath))),
          );
        }
        // Clean up temporary zip
        await File(zipPath).delete();
      }
    } catch (e) {
      _addLog('Error exporting configuration: $e');
    }
  }

  Future<void> _importConfiguration() async {
    final l10n = AppLocalizations.of(context)!;
    final passwordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) return;

      if (!mounted) return;

      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.importConfigTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter the password used to encrypt this backup."),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Decryption Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.importConfigButton),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      final zipFile = File(result.files.single.path!);
      final bytes = await zipFile.readAsBytes();
      final archive =
          ZipDecoder().decodeBytes(bytes, password: passwordController.text);

      for (final file in archive) {
        if (file.name == 'securemark_config.json') {
          final content = utf8.decode(file.content as List<int>);
          final Map<String, dynamic> configData = jsonDecode(content);
          final prefs = await SharedPreferences.getInstance();

          for (final entry in configData.entries) {
            final key = entry.key;
            final value = entry.value;

            if (value is bool) {
              await prefs.setBool(key, value);
            } else if (value is int) {
              await prefs.setInt(key, value);
            } else if (value is double) {
              await prefs.setDouble(key, value);
            } else if (value is String) {
              await prefs.setString(key, value);
            } else if (value is List) {
              // identity_bookmarks is stored as JSON string usually, but let's check
              if (key == 'identity_bookmarks') {
                await prefs.setString(key, jsonEncode(value));
              }
            }
          }

          // Reload all settings
          await _loadPreferences();
          await _loadBookmarks();

          messenger.showSnackBar(
            const SnackBar(
                content: Text(
                    "Configuration imported successfully. Restarting UI...")),
          );
          break;
        }
      }
    } catch (e) {
      _addLog('Error importing configuration: $e');
      messenger.showSnackBar(
        SnackBar(
            content: Text("Import failed: check password or file format.")),
      );
    }
  }

  void _showIdentityDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<String>>(
        future: Future.wait([
          IdentityManager.getDevicePublicKey(),
          IdentityManager.getDeviceFingerprint(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Loading Identity..."),
                ],
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            _addLog('ERROR in Identity dialog: ${snapshot.error}');
            return AlertDialog(
              title: Text(l10n.myIdentityTitle),
              content: Text("Error loading identity keys: ${snapshot.error}"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.close),
                ),
              ],
            );
          }

          final publicKey = snapshot.data![0];
          final fingerprint = snapshot.data![1];
          _addLog('Identity dialog loaded: fingerprint=$fingerprint');

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.person_pin_outlined, color: Colors.blue),
                const SizedBox(width: 12),
                Text(l10n.myIdentityTitle),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  TextField(
                    controller: _deviceNameController,
                    decoration: InputDecoration(
                      labelText: l10n.deviceNameLabel,
                      hintText: "e.g. My Secure Phone",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    onChanged: (value) {
                      _savePreference('deviceName', value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.myPublicKeyLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: publicKey),
                    readOnly: true,
                    maxLines: 2,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Fingerprint: $fingerprint',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          actions: [
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      final messenger = ScaffoldMessenger.of(context);
                      _addLog('Copying public key: $publicKey');
                      if (publicKey.isEmpty) {
                        _addLog('WARNING: Public key is empty!');
                      }
                      Clipboard.setData(ClipboardData(text: publicKey));
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.publicKeyCopied)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.copyPublicKey),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final shareData = jsonEncode({
                        'name': _deviceNameController.text,
                        'publicKey': publicKey,
                      });
                      SharePlus.instance.share(
                        ShareParams(
                          text: shareData,
                          subject: l10n.myIdentityTitle,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(l10n.sharePublicKey),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final qrData = jsonEncode({
                        'name': _deviceNameController.text,
                        'publicKey': publicKey,
                      });
                      _showQrIdentityDialog(qrData);
                    },
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: Text(l10n.generateQrKey),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.close),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQrIdentityDialog(String data) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.qrIdentityTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              width: 232, // explicit width (200 size + 32 padding)
              height: 232, // explicit height
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Recipients can scan this to verify your documents.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

class _DensityPainter extends CustomPainter {
  final double density;
  final Color color;
  final bool isPreview;
  final bool useRandomColor;

  _DensityPainter({
    required this.density,
    required this.color,
    this.isPreview = false,
    this.useRandomColor = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> randomPalette = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];
    final Random random =
        Random(42); // Seed for consistent randomness per frame

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Map density (10-90) to grid count (2-8)
    final count = ((density / 100) * 7 + 2).round();
    final stepX = size.width / (count + 1);
    final stepY = size.height / (count + 1);

    for (int i = 1; i <= count; i++) {
      for (int j = 1; j <= count; j++) {
        if (useRandomColor) {
          paint.color = randomPalette[random.nextInt(randomPalette.length)]
              .withValues(alpha: 0.6);
        }
        canvas.drawCircle(Offset(i * stepX, j * stepY), 3.0, paint);
      }
    }

    if (isPreview) {
      InlineSpan textSpan;
      if (useRandomColor) {
        // Each letter with a random color
        final String text = 'SecureMark';
        textSpan = TextSpan(
          children: text.split('').map((char) {
            return TextSpan(
              text: char,
              style: TextStyle(
                color: randomPalette[random.nextInt(randomPalette.length)],
                fontSize: 21,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            );
          }).toList(),
        );
      } else {
        textSpan = TextSpan(
          text: 'SecureMark',
          style: TextStyle(
            color: color,
            fontSize: 21,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        );
      }

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DensityPainter oldDelegate) {
    return oldDelegate.density != density ||
        oldDelegate.color != color ||
        oldDelegate.isPreview != isPreview ||
        oldDelegate.useRandomColor != useRandomColor;
  }
}

class _XYPadPainter extends CustomPainter {
  final double x;
  final double y;
  final Color color;

  _XYPadPainter({required this.x, required this.y, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    // Vertical line
    canvas.drawLine(
        Offset(x * size.width, 0), Offset(x * size.width, size.height), paint);
    // Horizontal line
    canvas.drawLine(
        Offset(0, y * size.height), Offset(size.width, y * size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _XYPadPainter oldDelegate) =>
      oldDelegate.x != x || oldDelegate.y != y || oldDelegate.color != color;
}

class _ComparisonClipper extends CustomClipper<Rect> {
  final double value;
  final bool isVertical; // true for vertical line (left-right drag), false for horizontal line (up-down drag)

  _ComparisonClipper(this.value, {this.isVertical = true});

  @override
  Rect getClip(Size size) {
    if (isVertical) {
      return Rect.fromLTRB(0, 0, size.width * value, size.height);
    } else {
      return Rect.fromLTRB(0, 0, size.width, size.height * value);
    }
  }

  @override
  bool shouldReclip(_ComparisonClipper oldClipper) =>
      oldClipper.value != value || oldClipper.isVertical != isVertical;
}

class _GradientButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final List<Color> gradientColors;
  final bool enabled;

  const _GradientButton({
    required this.child,
    this.onTap,
    required this.gradientColors,
    this.enabled = true,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Listener(
      onPointerDown: widget.enabled
          ? (_) => setState(() => _isPressed = true)
          : null,
      onPointerUp: widget.enabled
          ? (_) => setState(() => _isPressed = false)
          : null,
      onPointerCancel: widget.enabled
          ? (_) => setState(() => _isPressed = false)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? 4.0 : 0.0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: widget.enabled
              ? LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: widget.enabled
              ? null
              : theme.colorScheme.surfaceContainerHighest,
          boxShadow: (widget.enabled && !_isPressed)
              ? [
                  BoxShadow(
                    color: widget.gradientColors.first.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _PushDownWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _PushDownWrapper({required this.child, this.enabled = true});

  @override
  State<_PushDownWrapper> createState() => _PushDownWrapperState();
}

class _PushDownWrapperState extends State<_PushDownWrapper> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Listener(
      onPointerDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onPointerUp: widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onPointerCancel: widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? 4.0 : 0.0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: (widget.enabled && !_isPressed)
              ? [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}
