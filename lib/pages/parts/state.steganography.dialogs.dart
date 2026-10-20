part of '../watermark_page.dart';

/// Steganography, QR watermark, fonts and expert options dialogs.

// -------- Library-level declarations (kept private) --------

const Map<String, Color> _uiColorSchemes = {
  'Deep Purple (Default)': Colors.deepPurple,
  'Professional Blue': Colors.blue,
  'Security Red': Colors.red,
  'Nature Green': Colors.green,
  'Stealth Black': Colors.black,
  'High-Visibility Orange': Colors.orange,
  'Corporate Gray': Colors.blueGrey,
};

extension _WatermarkPageStateSteganographyDialogsPart on WatermarkPageState {
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
                          if (enabled && _jpegQuality < 85) {
                            _jpegQuality = 85;
                            _savePreference('jpegQuality', 85);
                          }
                        });
                        _refresh(() {
                          _useSteganography = enabled;
                          if (enabled && _jpegQuality < 85) {
                            _jpegQuality = 85;
                          }
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
                          if (enabled && _jpegQuality < 85) {
                            _jpegQuality = 85;
                            _savePreference('jpegQuality', 85);
                          }
                        });
                        _refresh(() {
                          _useRobustSteganography = enabled;
                          if (enabled && _jpegQuality < 85) {
                            _jpegQuality = 85;
                          }
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
                            _refresh(() {
                              _obscureHidingPassword = newValue;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureHidingPassword,
                      onChanged: (value) {
                        _refresh(() => _hidingPassword = value);
                        _savePreference('hidingPassword', value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Note: This password will be required to see signature and the hidden file using SecureMark. It uses AES-256 encryption.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    // File hiding is not part of the web UI.
                    if (!kIsWeb)
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
                          _refresh(() {
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
                            _refresh(() {
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
                            _refresh(() {
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
                          _refresh(() => _qrVisible = value ?? false);
                          _savePreference('qrVisible', value ?? false);
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.qrContentType,
                          style: theme.textTheme.titleSmall),
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
                                _refresh(() => _qrType = value);
                                _savePreference('qrType', value.index);
                              }
                            },
                            items: [
                              DropdownMenuItem(
                                  value: QrType.metadata,
                                  child: Text(l10n.qrTypeMetadata)),
                              DropdownMenuItem(
                                  value: QrType.url,
                                  child: Text(l10n.qrTypeUrl)),
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
                            _refresh(() => _qrAuthor = value);
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
                            _refresh(() => _qrUrl = value);
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
                            _refresh(() => _qrUrl = value);
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
                                  _refresh(() => _vCardFirstName = value);
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
                                  _refresh(() => _vCardLastName = value);
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
                            _refresh(() => _vCardPhone = value);
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
                            _refresh(() => _vCardEmail = value);
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
                            _refresh(() => _vCardOrg = value);
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
                                  _refresh(() => _qrPosition = value);
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
                            _refresh(() => _qrSize = value);
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
                            _refresh(() => _qrOpacity = value);
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
                                                ? (kIsWeb
                                                    // The web build ships no PDF
                                                    // rasterizer: show the document
                                                    // icon instead of attempting a
                                                    // page render.
                                                    ? Icon(
                                                        Icons.picture_as_pdf,
                                                        size: 40,
                                                        color: theme.colorScheme
                                                            .outlineVariant,
                                                      )
                                                    : FutureBuilder<Uint8List>(
                                                        future: () async {
                                                          final bytes = kIsWeb
                                                              ? WebFileStore
                                                                  .bytesFor(
                                                                      path)
                                                              : await File(path)
                                                                  .readAsBytes();
                                                          if (bytes == null) {
                                                            throw StateError(
                                                                'No in-memory bytes for $path');
                                                          }
                                                          final preview =
                                                              await Printing
                                                                      .raster(
                                                                          bytes,
                                                                          pages: [
                                                                            0
                                                                          ],
                                                                          dpi:
                                                                              72)
                                                                  .first;
                                                          return await preview
                                                              .toPng();
                                                        }(),
                                                        builder: (context,
                                                            snapshot) {
                                                          if (snapshot
                                                              .hasData) {
                                                            return Image.memory(
                                                              snapshot.data!,
                                                              fit: BoxFit.cover,
                                                              width: double
                                                                  .infinity,
                                                              height: double
                                                                  .infinity,
                                                            );
                                                          }

                                                          return Icon(
                                                              Icons
                                                                  .picture_as_pdf,
                                                              size: 40,
                                                              color: theme
                                                                  .colorScheme
                                                                  .error);
                                                        },
                                                      ))
                                                : Builder(
                                                    builder: (itemContext) {
                                                      final webBytes = kIsWeb
                                                          ? WebFileStore
                                                              .bytesFor(path)
                                                          : null;
                                                      // On web the source
                                                      // bytes come from the
                                                      // in-memory store; an
                                                      // empty buffer falls
                                                      // through to the
                                                      // errorBuilder below.
                                                      if (webBytes != null) {
                                                        return Image.memory(
                                                          webBytes,
                                                          fit: BoxFit.cover,
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
                                                          errorBuilder: (context,
                                                                  error,
                                                                  stackTrace) =>
                                                              const Icon(Icons
                                                                  .broken_image),
                                                        );
                                                      }
                                                      return Image.file(
                                                        File(path),
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                        errorBuilder: (context,
                                                                error,
                                                                stackTrace) =>
                                                            const Icon(Icons
                                                                .broken_image),
                                                      );
                                                    },
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
                                        _refresh(() {
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
                                              color: ColorUtils
                                                  .getAdaptiveShadowColor(theme,
                                                      alpha: 0.2),
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
                  const Icon(Icons.image_outlined),
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
                        _refresh(() {
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
                              _refresh(() {
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
                    const Divider(height: 32),
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
                            _refresh(() {
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
                      value: _jpegQuality.toDouble().clamp(
                          (_useSteganography || _useRobustSteganography)
                              ? 85.0
                              : 10.0,
                          100.0),
                      min: (_useSteganography || _useRobustSteganography)
                          ? 85
                          : 10,
                      max: 100,
                      divisions: (_useSteganography || _useRobustSteganography)
                          ? 15
                          : 18,
                      onChanged: (value) {
                        setDialogState(() {
                          _jpegQuality = value.round();
                        });
                        _refresh(() {
                          _jpegQuality = value.round();
                        });
                        _savePreference('jpegQuality', value.round());
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: Text(l10n.forcePngTitle),
                      subtitle: Text(l10n.forcePngSubtitle),
                      value: _forcePng,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        final bool enabled = value ?? false;
                        setDialogState(() {
                          _forcePng = enabled;
                        });
                        _refresh(() {
                          _forcePng = enabled;
                        });
                        _savePreference('forcePng', enabled);
                      },
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
                        // The prefix must stay a plain filename fragment:
                        // strip path separators and friends so the output
                        // can never escape its directory (see
                        // WatermarkUtils.sanitizeFilePrefix).
                        final sanitized =
                            WatermarkUtils.sanitizeFilePrefix(value);
                        _refresh(() {
                          _filePrefix = sanitized;
                        });
                        if (sanitized != value) {
                          _filePrefixController.text = sanitized;
                        }
                        _savePreference('filePrefix', sanitized);
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
                        _refresh(() {
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
                        _refresh(() {
                          _preserveMetadata = value ?? false;
                        });
                        _savePreference('preserveMetadata', value ?? false);
                      },
                    ),
                    // Flattening rasterizes every page, which the web build
                    // cannot do: keep the option out of the web UI.
                    if (!kIsWeb)
                      CheckboxListTile(
                        title: Text(l10n.rasterizePdfTitle),
                        subtitle: Text(l10n.rasterizePdfSubtitle),
                        value: _rasterizePdf,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setDialogState(() {
                            _rasterizePdf = value ?? false;
                          });
                          _refresh(() {
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
                        _refresh(() {
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
                            _refresh(() {
                              _obscureSecureZipPassword = newValue;
                            });
                          },
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty && _useSecureZip) {
                          setDialogState(() {
                            _useSecureZip = false;
                          });
                          _refresh(() {
                            _useSecureZip = false;
                          });
                          _savePreference('useSecureZip', false);
                        }
                        _savePreference('secureZipPassword', value);
                        // Trigger UI update for the grid icon availability
                        _refresh(() {});
                      },
                      controller: _secureZipPasswordController,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: Text(l10n.enableSecureZip),
                      value: _useSecureZip,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        final bool enabled = value ?? false;
                        if (enabled &&
                            _secureZipPasswordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.secureZipPasswordRequired),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                          return;
                        }
                        setDialogState(() {
                          _useSecureZip = enabled;
                        });
                        _refresh(() {
                          _useSecureZip = enabled;
                        });
                        _savePreference('useSecureZip', enabled);
                      },
                    ),
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
                        _refresh(() {
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
                          _refresh(() {
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
                          _refresh(() {
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
                          _refresh(() {
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
                    /*
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
                            _refresh(() {
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
                      min: (_useSteganography || _useRobustSteganography) ? 85 : 10,
                      max: 100,
                      divisions: (_useSteganography || _useRobustSteganography) ? 15 : 18,
                      onChanged: (value) {
                        setDialogState(() {
                          _jpegQuality = value.round();
                        });
                        _refresh(() {
                          _jpegQuality = value.round();
                        });
                        _savePreference('jpegQuality', value.round());
                      },
                    ),
                    */
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
                        _refresh(() {
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
                        _refresh(() {
                          _useAiCloaking = enabled;
                        });
                        _savePreference('useAiCloaking', enabled);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(l10n.uiThemeColor, style: theme.textTheme.titleSmall),
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
                              : Colors.blue,
                          isExpanded: true,
                          onChanged: (Color? newValue) {
                            if (newValue != null) {
                              SecureMarkApp.of(context).setSeedColor(newValue);
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
                                      border:
                                          Border.all(color: theme.dividerColor),
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
                    const SizedBox(height: 16),
                    Text(
                      l10n.languageLabel,
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
                        child: DropdownButton<Locale?>(
                          value: SecureMarkApp.of(context).appLocale,
                          isExpanded: true,
                          // null = follow the device system locale; language
                          // names are shown in their own language
                          items: [
                            DropdownMenuItem<Locale?>(
                              value: null,
                              child: Text(l10n.languageSystem),
                            ),
                            DropdownMenuItem<Locale?>(
                              value: const Locale('en'),
                              child: Text('English'),
                            ),
                            DropdownMenuItem<Locale?>(
                              value: const Locale('fr'),
                              child: Text('Français'),
                            ),
                            DropdownMenuItem<Locale?>(
                              value: const Locale('de'),
                              child: Text('Deutsch'),
                            ),
                            DropdownMenuItem<Locale?>(
                              value: const Locale('es'),
                              child: Text('Español'),
                            ),
                            DropdownMenuItem<Locale?>(
                              value: const Locale('it'),
                              child: Text('Italiano'),
                            ),
                          ],
                          onChanged: (locale) {
                            SecureMarkApp.of(context).setLocale(locale);
                            setDialogState(() {});
                          },
                        ),
                      ),
                    ),
                    if (!kIsWeb) ...[
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

                        _refresh(() {
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
                    // Log export and config backup/restore are not part of
                    // the web UI: the backup contains the identity private
                    // key, and handing it (or a log) to the browser as a
                    // downloaded file is an unnecessary exposure on a
                    // shared machine. The in-app log dialog stays reachable
                    // from the error banner for on-screen diagnostics.
                    if (!kIsWeb) ...[
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
                    ],
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

  IconData _getFeatureIcon(String key) {
    switch (key) {
      case 'steganographyTitle':
        return _steganographyVerificationFailed
            ? Icons.gpp_bad
            : Icons.verified_user_outlined;
      case 'robustSteganographyTitle':
        return Icons.shield_outlined;
      case 'digitallySignTitle':
        return Icons.fingerprint;
      case 'aiCloakingTitle':
        return Icons.visibility_off_outlined;
      case 'antiAiProtectionTitle':
        return Icons.auto_awesome;
      case 'qrWatermarkTitle':
        return Icons.qr_code_2;
      case 'rasterizePdfTitle':
        return Icons.picture_as_pdf;
      case 'preserveMetadata':
        return Icons.info_outline;
      case 'pdfSecurityTitle':
        return Icons.lock_outline;
      case 'imageResizingTitle':
        return Icons.photo_size_select_large;
      case 'forcePngTitle':
        return Icons.image_search_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  Color _getFeatureColor(String key) {
    switch (key) {
      case 'steganographyTitle':
        return _steganographyVerificationFailed ? Colors.red : Colors.green;
      case 'robustSteganographyTitle':
        return Colors.indigo;
      case 'digitallySignTitle':
        return Colors.blueAccent;
      case 'aiCloakingTitle':
        return Colors.teal;
      case 'antiAiProtectionTitle':
        return Colors.purple;
      case 'qrWatermarkTitle':
        return Colors.blue;
      case 'rasterizePdfTitle':
        return Colors.redAccent;
      case 'preserveMetadata':
        return Colors.lightBlue;
      case 'pdfSecurityTitle':
        return Colors.orange;
      case 'imageResizingTitle':
        return Colors.orange;
      case 'forcePngTitle':
        return Colors.blueGrey;
      default:
        return Colors.blueGrey;
    }
  }

  String _getFeatureLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'steganographyTitle':
        return _steganographyVerificationFailed
            ? l10n.steganographyVerificationFailed
            : l10n.steganographyTitle;
      case 'robustSteganographyTitle':
        return l10n.robustSteganographyTitle;
      case 'digitallySignTitle':
        return l10n.digitallySignTitle;
      case 'aiCloakingTitle':
        return l10n.aiCloakingTitle;
      case 'antiAiProtectionTitle':
        return l10n.antiAiProtectionTitle;
      case 'qrWatermarkTitle':
        return l10n.qrWatermarkTitle;
      case 'rasterizePdfTitle':
        return l10n.rasterizePdfTitle;
      case 'preserveMetadata':
        return l10n.preserveMetadata;
      case 'pdfSecurityTitle':
        return l10n.pdfSecurityTitle;
      case 'imageResizingTitle':
        return l10n.imageResizingTitle;
      case 'forcePngTitle':
        return l10n.forcePngTitle;
      default:
        return "";
    }
  }
}
