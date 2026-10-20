part of '../watermark_page.dart';

/// Watermark image/logo selection, colors, fonts and QR validation.

extension _WatermarkPageStateWatermarkEditingPart on WatermarkPageState {
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
          _refresh(() {
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
        _refresh(() {
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
      _refresh(() {
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

  void _updateColorMode(bool useRandomColor) {
    _refresh(() {
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
    _refresh(() {
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
}
