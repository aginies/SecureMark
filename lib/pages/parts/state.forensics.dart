part of '../watermark_page.dart';

/// File forensics: extraction, batch analysis, signature verification and results UI.

extension _WatermarkPageStateForensicsPart on WatermarkPageState {
  /// Clears every analysis-related field so the analyzer always starts from a
  /// clean slate (shared by the dialog entry points).
  void _resetAnalysisState() {
    _analysisResult = null;
    _extractedFile = null;
    _batchAnalysisResult = null;
    _selectedFileIndex = null;
    _extractedSignature = null;
    _verificationResult = null;
    _integrityVerified = false;
    _senderPublicKey = null;
    _analyzingFile = false;
  }

  void _showFileAnalyzer(
      {Uint8List? autoAnalyzeBytes, String? autoAnalyzeName}) {
    final l10n = AppLocalizations.of(context)!;

    _refresh(() {
      _extractionPassword = '';
      _extractionPasswordController.text = '';
      // Reset analysis state
      _resetAnalysisState();
    });

    showDialog(
      context: context,
      builder: (context) {
        bool isDragging = false;
        bool autoAnalyzeStarted = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);

            // Auto-verify entry point: run the analysis once the dialog is
            // on screen (used by the received-file badge).
            if (!autoAnalyzeStarted &&
                autoAnalyzeBytes != null &&
                autoAnalyzeName != null) {
              autoAnalyzeStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _performFileAnalysis(
                    autoAnalyzeBytes, autoAnalyzeName, setDialogState);
              });
            }

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
                          _refresh(() {
                            _obscureExtractionPassword = newValue;
                          });
                        },
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        _extractionPassword = value;
                      });
                      _refresh(() {
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

  Future<void> _pickAndAnalyze(StateSetter setDialogState) async {
    // Reset state FIRST before picking new file
    setDialogState(_resetAnalysisState);

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

  /// Background integrity check for files received over the local network.
  /// Shows a short badge; the full verification card opens on demand via
  /// the badge's details action.
  Future<void> _autoVerifyReceivedFile(
      String sourcePath, String fileName) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return;
      final bytes = await source.readAsBytes();
      final analysis =
          await WatermarkProcessor.analyzeFileAsync(bytes, fileName);
      if (!mounted) return;

      _receivedFileBytes = bytes;
      _receivedFileName = fileName;

      final l10n = AppLocalizations.of(context)!;
      final Color badgeColor;
      final String message;
      if (analysis.senderPublicKey != null) {
        if (analysis.integrityVerified) {
          badgeColor = Colors.green;
          message = l10n.autoVerifyVerified;
        } else {
          badgeColor = Colors.red;
          message = l10n.autoVerifyTampered;
        }
      } else if (analysis.signature != null ||
          analysis.robustSignature != null ||
          analysis.file != null) {
        badgeColor = Colors.blue;
        message = l10n.autoVerifyHasMarks;
      } else {
        badgeColor = Colors.orange;
        message = l10n.autoVerifyNoMarks;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: badgeColor,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l10n.viewDetails,
            onPressed: _showReceivedFileDetails,
          ),
        ),
      );
    } catch (e) {
      _addLog('Auto-verify failed for $fileName: $e');
    }
  }

  /// Re-opens the file analyzer and runs the full analysis on the last
  /// received file, showing the complete verification card.
  void _showReceivedFileDetails() {
    final bytes = _receivedFileBytes;
    final name = _receivedFileName;
    if (bytes == null || name == null) return;
    _showFileAnalyzer(autoAnalyzeBytes: bytes, autoAnalyzeName: name);
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
}
