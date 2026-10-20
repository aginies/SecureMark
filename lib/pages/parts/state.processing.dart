part of '../watermark_page.dart';

/// Watermark processing pipeline, saving, sharing, zipping and progress reporting.

extension _WatermarkPageStateProcessingPart on WatermarkPageState {
  Future<Uint8List> _createProcessedZipBytes() async {
    final archive = Archive();
    for (final file in _processedFiles) {
      final fileName = p.basename(file.result.outputPath);
      archive.addFile(ArchiveFile(
          fileName, file.result.outputBytes.length, file.result.outputBytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Web output path: a single file is downloaded directly, several files
  /// (or the zip toggle) become one zip download.
  Future<void> _downloadProcessedFiles() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (_zipOutputs || _processedFiles.length > 1) {
        final bytes = await _createProcessedZipBytes();
        final now = DateTime.now();
        final timestamp =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
        browserDownload(
            bytes, 'securemark-files-$timestamp.zip', 'application/zip');
      } else {
        final file = _processedFiles.first;
        final name = p.basename(file.result.outputPath);
        browserDownload(file.result.outputBytes, name, _mimeTypeForPath(name));
      }
      if (mounted) {
        _refresh(() {
          _statusMessage = l10n.downloadStarted;
          _hasErrors = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _refresh(() {
        _statusMessage = l10n.errorPrefix(e.toString());
        _hasErrors = true;
      });
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

    _refresh(() {
      _processing = true;
      _hasErrors = false;
      _processedFiles = <ProcessedFile>[];
      _previewIndex = 0;
      _progress = 0.0;
      _progressMessage = '';
      _elapsedTime = '00:00';
      _modalProgressStatus = l10n.processingCount(paths.length);
      _statusMessage = '';
    });

    bool dialogOpened = false;
    final processedFiles = <ProcessedFile>[];
    final failedFiles = <String>[];
    final processingErrors = <String, String>{};

    try {
      await _cleanupTempFiles();

      if (!mounted) return;

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
                  ? (_modalProgressStatus.isEmpty
                      ? l10n.processingFile
                      : _modalProgressStatus)
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
                    if (_processing && _modalProgressStatus.isNotEmpty) ...[
                      Text(
                        _modalProgressStatus,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
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

      for (var i = 0; i < paths.length; i++) {
        if (_cancellationToken?.isCancelled == true) {
          _addLog('Processing cancelled by user');
          break;
        }

        final path = paths[i];
        final fileName = p.basename(path);

        if (!mounted) break;

        _addLog('Starting file $i: $fileName');

        _refresh(() {
          _modalProgressStatus =
              l10n.processingNamedFile(i + 1, paths.length, fileName);
          _statusMessage = '';
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

        // When signing with the device identity, the identity (device name)
        // is drawn as a visible watermark in a random color, so the signature
        // is apparent on the image and not only cryptographically embedded.
        final identityName = _deviceName.trim();
        final bool applyIdentityWatermark =
            _digitallySign && identityName.isNotEmpty;
        final String effectiveWatermarkText = applyIdentityWatermark
            ? (_textController.text.trim().isEmpty
                ? identityName
                : '${_textController.text.trim()} — $identityName')
            : _textController.text;
        final bool effectiveRandomColor =
            applyIdentityWatermark || _useRandomColor;

        _addLog(
            'Processing with: useSteganography=$shouldApplyStegano, hideFile=$_hideFileWithSteganography, hiddenFile=$_hiddenFileName (${_hiddenFileBytes?.length ?? 0} bytes), digitallySign=$_digitallySign');

        try {
          final result = await WatermarkProcessor.processFile(
            file: File(path),
            // On web the bytes are in memory (no filesystem in the browser).
            inputBytes: kIsWeb ? WebFileStore.bytesFor(path) : null,
            transparency: _transparency,
            density: _density,
            watermarkText: effectiveWatermarkText,
            useRandomColor: effectiveRandomColor,
            selectedColorValue: _selectedColor.toARGB32(),
            fontSize:
                _watermarkType == WatermarkType.text ? _fontSize : _logoSize,
            font: _selectedFont,
            jpegQuality: _jpegQuality,
            targetSize: _targetSize,
            forcePng: _forcePng,
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
                _refresh(() {
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

            _refresh(() {
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
          _refresh(() {
            _processing = false;
            _progress = 0.0;
            _progressMessage = '';
            _modalProgressStatus = '';
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
          } else if (steganographyFailed) {
            successMessage = l10n.steganographyVerificationFailed;
          }

          _refresh(() {
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

            if (_statusMessage.isEmpty || !hasDetailedError) {
              _statusMessage = successMessage;
            }
            _hasErrors = processingErrors.isNotEmpty || steganographyFailed;
            _processing = false;
            _progress = 1.0;
            _steganographyVerificationFailed = steganographyFailed;
            _progressMessage = '';
            _modalProgressStatus = '';
          });

          // Web-only: (re)start the 2-minute in-memory retention window.
          _webStartRetentionWindow();

          if (_previewController.hasClients) {
            _previewController.jumpToPage(0);
          }
        }
      }
    }
  }

  void _cancelProcessing() {
    final l10n = AppLocalizations.of(context)!;
    _cancellationToken?.cancel();
    _stopStopwatch();
    _refresh(() {
      _processing = false;
      _progress = 0.0;
      _progressMessage = '';
      _modalProgressStatus = '';
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
        _refresh(() {
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

      // Reset app theme and seed color to defaults
      if (mounted) {
        final appState = SecureMarkApp.of(context);
        await appState.setThemeMode(AppTheme.system);
        await appState.setSeedColor(Colors.blue);
      }
    } catch (e) {
      _addLog('Error clearing preferences: $e');
    }

    WatermarkProcessor.clearCache();
    WebFileStore.clear();
    _webRetentionTimer?.cancel();
    _webRetentionTimer = null;
    _webRetentionDeadline = null;
    await _cleanupTempFiles();

    if (_previewController.hasClients) {
      _previewController.jumpToPage(0);
    }
    _refresh(() {
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
      _verificationResult = null;
      _hasErrors = false;
      _extractedSignature = null;
      _statusMessage = '';
      _modalProgressStatus = '';
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

  Future<void> _applyWatermark() async {
    if (_selectedPaths.isEmpty) {
      return;
    }

    // Validate QR code content if QR is enabled
    if (_qrVisible && !_isQrContentValid()) {
      _showQrWatermarkOptions();
      return;
    }

    _refresh(() {
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

    // On web there is no filesystem to save to — hand the results to the
    // browser as a download instead.
    if (kIsWeb) {
      await _downloadProcessedFiles();
      return;
    }

    _refresh(() {
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

      _refresh(() {
        _statusMessage = statusMessage;
        _hasErrors = failedFiles.isNotEmpty;
      });

      if (savedFiles.isNotEmpty && mounted) {
        _showSaveResultDialog(savedFiles, failedFiles);
      }
    } catch (e) {
      if (!mounted) return;

      _refresh(() {
        _statusMessage = l10n.errorSavingFiles(e.toString());
        _hasErrors = true;
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

    // Web has no share sheet and no LAN server: hand the files to the
    // browser as a download instead.
    if (kIsWeb) {
      await _downloadProcessedFiles();
      return;
    }

    try {
      final shareFiles = <XFile>[];

      if (_zipOutputs) {
        final zipPath =
            await _createZipFromProcessedFiles(_processedFiles, true);
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

      _refresh(() {
        _statusMessage = result.status == ShareResultStatus.success
            ? l10n.sharedFiles(_processedFiles.length)
            : l10n.shareOpenedFiles(_processedFiles.length);
        _hasErrors = false;
      });
    } catch (e) {
      if (!mounted) return;
      _refresh(() {
        _statusMessage = l10n.errorPrefix(e.toString());
        _hasErrors = true;
      });
    }
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
}
