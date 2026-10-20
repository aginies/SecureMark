part of '../watermark_page.dart';

/// Preference loading/saving, bookmark and profile management for [WatermarkPageState].

extension _WatermarkPageStatePreferencesPart on WatermarkPageState {
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? bookmarksJson = prefs.getString('identity_bookmarks');
    if (bookmarksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(bookmarksJson);
        _refresh(() {
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

      String? outputDir = prefs.getString('outputDirectory');
      if (outputDir == null && !kIsWeb && Platform.isMacOS) {
        try {
          final directory = await getDownloadsDirectory();
          if (directory != null) {
            outputDir = directory.path;
            _addLog('Default macOS output directory set to: $outputDir');
          }
        } catch (e) {
          _addLog('Error setting default macOS output directory: $e');
        }
      }

      if (mounted) {
        _refresh(() {
          _transparency = prefs.getDouble('transparency') ?? 75.0;
          _density = prefs.getDouble('density') ?? 35.0;
          _fontSize = prefs.getDouble('fontSize') ?? 24.0;
          _jpegQuality = prefs.getInt('jpegQuality') ?? 75;
          _forcePng = prefs.getBool('forcePng') ?? false;
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

          // Enforce 85% minimum JPEG quality for steganography
          if (_useSteganography || _useRobustSteganography) {
            if (_jpegQuality < 85) {
              _jpegQuality = 85;
            }
          }
          _hideFileWithSteganography =
              prefs.getBool('hideFileWithSteganography') ?? false;
          // File hiding is not exposed in the web UI: force it off so a
          // setting persisted on another platform cannot linger invisibly.
          if (kIsWeb) {
            _hideFileWithSteganography = false;
          }
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
          _outputDirectory = outputDir;

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
      if (value is num) {
        if (_isIntPreferenceKey(key)) {
          await prefs.setInt(key, value.toInt());
          // Clear the null flag if we're setting a value for targetSize
          if (key == 'targetSize') {
            await prefs.remove('targetSizeIsNull');
          }
        } else {
          await prefs.setDouble(key, value.toDouble());
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
    _refresh(() {
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
        _forcePng = false;
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

    _refresh(() {
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
      if (prefs.containsKey('${pKey}forcePng')) {
        _forcePng = prefs.getBool('${pKey}forcePng')!;
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

      // Enforce 85% minimum JPEG quality for steganography after loading states
      if (_useSteganography || _useRobustSteganography) {
        if (_jpegQuality < 85) {
          _jpegQuality = 85;
        }
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
    _refresh(() {
      switch (profile) {
        case SettingsProfile.none:
          break;

        case SettingsProfile.secureIdentity:
          if (!prefs.containsKey('${pKey}targetSize')) {
            _targetSize = 1280;
          }
          // Signed document: a subtle visible watermark carrying the device
          // identity (drawn in _applyWatermark when signing) in a random
          // color — less visible than the Image profile (transparency 50) —
          // backed by the Ed25519 digital signature for integrity. No
          // steganography.
          if (!prefs.containsKey('${pKey}transparency')) {
            _transparency = 75;
          }
          if (!prefs.containsKey('${pKey}density')) {
            _density = 50;
          }
          if (!prefs.containsKey('${pKey}jpegQuality')) {
            _jpegQuality = 75;
          }
          if (!prefs.containsKey('${pKey}antiAiLevel')) {
            _antiAiLevel = 100;
          }
          if (!prefs.containsKey('${pKey}useAiCloaking')) {
            _useAiCloaking = true;
          }
          if (!prefs.containsKey('${pKey}digitallySign')) {
            _digitallySign = true;
          }
          // Digital signing requires ZIP output to carry the integrity
          // metadata (the ZIP toggle is locked on while signing).
          _zipOutputs = true;
          if (!prefs.containsKey('${pKey}useSteganography')) {
            _useSteganography = false;
          }
          if (!prefs.containsKey('${pKey}useRobustSteganography')) {
            _useRobustSteganography = false;
          }
          if (!prefs.containsKey('${pKey}useRandomColor')) {
            _useRandomColor = true;
          }
          if (!prefs.containsKey('${pKey}watermarkType')) {
            _watermarkType = WatermarkType.text;
          }
          if (!prefs.containsKey('${pKey}filePrefix')) {
            _filePrefix = 'id-';
            _filePrefixController.text = _filePrefix;
          }
          break;

        case SettingsProfile.onlineImage:
          // ZIP output is on by default only for the Identity/Integrity
          // profiles; keep it off here.
          _zipOutputs = false;
          if (!prefs.containsKey('${pKey}useSteganography')) {
            _useSteganography = false;
          }
          if (!prefs.containsKey('${pKey}useRobustSteganography')) {
            _useRobustSteganography = false;
          }
          if (!prefs.containsKey('${pKey}useAiCloaking')) {
            _useAiCloaking = true;
          }
          if (!prefs.containsKey('${pKey}antiAiLevel')) {
            _antiAiLevel = 100;
          }
          if (!prefs.containsKey('${pKey}transparency')) {
            _transparency = 50;
          }
          if (!prefs.containsKey('${pKey}density')) {
            _density = 50;
          }
          if (!prefs.containsKey('${pKey}useRandomColor')) {
            _useRandomColor = true;
          }
          if (!prefs.containsKey('${pKey}targetSize')) {
            _targetSize = 1024;
          }
          if (!prefs.containsKey('${pKey}jpegQuality')) {
            _jpegQuality = 70;
          }
          if (!prefs.containsKey('${pKey}filePrefix')) {
            _filePrefix = 'image';
            _filePrefixController.text = _filePrefix;
          }
          break;

        case SettingsProfile.qrCode:
          // ZIP output is on by default only for the Identity/Integrity
          // profiles; keep it off here.
          _zipOutputs = false;
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

        case SettingsProfile.integrity:
          // Integrity signs documents, so ZIP output is required (as with the
          // Identity profile); keep it on by default.
          _zipOutputs = true;
          if (!prefs.containsKey('${pKey}targetSize')) _targetSize = 1280;
          if (!prefs.containsKey('${pKey}transparency')) _transparency = 50;
          if (!prefs.containsKey('${pKey}density')) _density = 50;
          if (!prefs.containsKey('${pKey}jpegQuality')) _jpegQuality = 75;
          if (!prefs.containsKey('${pKey}antiAiLevel')) _antiAiLevel = 100;
          if (!prefs.containsKey('${pKey}useAiCloaking')) _useAiCloaking = true;
          if (!prefs.containsKey('${pKey}digitallySign')) _digitallySign = true;
          if (!prefs.containsKey('${pKey}useSteganography')) {
            _useSteganography = true;
          }
          if (!prefs.containsKey('${pKey}useRobustSteganography')) {
            _useRobustSteganography = true;
          }
          if (!prefs.containsKey('${pKey}useRandomColor')) {
            _useRandomColor = true;
          }
          if (!prefs.containsKey('${pKey}watermarkType')) {
            _watermarkType = WatermarkType.text;
          }
          if (!prefs.containsKey('${pKey}filePrefix')) {
            _filePrefix = 'verified-';
            _filePrefixController.text = _filePrefix;
          }
          break;

        case SettingsProfile.shareDocument:
          // ZIP output is on by default only for the Identity/Integrity
          // profiles; keep it off here.
          _zipOutputs = false;
          if (!prefs.containsKey('${pKey}targetSize')) _targetSize = 1280;
          // The visible watermark uses the same subtle opacity/density as the
          // Identity profile (transparency 75, density 50), so a Doc carries a
          // light, visible mark; steganography is off.
          if (!prefs.containsKey('${pKey}transparency')) _transparency = 75;
          if (!prefs.containsKey('${pKey}density')) _density = 50;
          if (!prefs.containsKey('${pKey}jpegQuality')) _jpegQuality = 80;
          if (!prefs.containsKey('${pKey}antiAiLevel')) _antiAiLevel = 75;
          if (!prefs.containsKey('${pKey}useAiCloaking')) _useAiCloaking = true;
          if (!prefs.containsKey('${pKey}useSteganography')) {
            _useSteganography = false;
          }
          if (!prefs.containsKey('${pKey}useRobustSteganography')) {
            _useRobustSteganography = false;
          }
          if (!prefs.containsKey('${pKey}filePrefix')) {
            _filePrefix = 'doc-';
            _filePrefixController.text = _filePrefix;
          }
          break;

        case SettingsProfile.p1:
          // ZIP output is on by default only for the Identity/Integrity
          // profiles; keep it off here.
          _zipOutputs = false;
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

        case SettingsProfile.p2:
          // ZIP output is on by default only for the Identity/Integrity
          // profiles; keep it off here.
          _zipOutputs = false;
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
            _filePrefix = 'p2-';
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
    _savePreference('forcePng', _forcePng);
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
                case SettingsProfile.integrity:
                  label = l10n.profileIntegrity;
                  icon = Icons.verified_outlined;
                case SettingsProfile.shareDocument:
                  label = l10n.profileShareDocument;
                  icon = Icons.description;
                case SettingsProfile.p1:
                  label = "P1";
                  icon = Icons.tune;
                case SettingsProfile.p2:
                  label = "P2";
                  icon = Icons.tune;
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
}
