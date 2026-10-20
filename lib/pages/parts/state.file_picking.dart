part of '../watermark_page.dart';

/// File, photo, and document-scan picking plus platform shared-content handling.

// -------- Library-level declarations (kept private) --------

const MethodChannel _platform = MethodChannel('secure_mark/sharing');

extension _WatermarkPageStateFilePickingPart on WatermarkPageState {
  Future<void> _pickOutputDirectory() async {
    try {
      String? directoryPath;
      if (!kIsWeb && Platform.isAndroid) {
        directoryPath = await FilePicker.platform.getDirectoryPath();
      } else {
        directoryPath = await getDirectoryPath();
      }

      if (directoryPath != null) {
        _addLog('Selected output directory: $directoryPath');
        _refresh(() {
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
      String? directoryPath;
      if (!kIsWeb && Platform.isAndroid) {
        directoryPath = await FilePicker.platform.getDirectoryPath(
          initialDirectory: _logoDirectory,
        );
      } else {
        directoryPath =
            await getDirectoryPath(initialDirectory: _logoDirectory);
      }

      if (directoryPath != null) {
        _addLog('Selected logo directory: $directoryPath');
        _refresh(() {
          _logoDirectory = directoryPath;
        });
        _savePreference('logoDirectory', directoryPath);
      }
    } catch (e) {
      _addLog('Error picking logo directory: $e');
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
            _refresh(() {
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
      _refresh(() => _loadingFiles = true);
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
        _refresh(() => _loadingFiles = true);
        if (kIsWeb) {
          // The web camera hands back in-memory bytes only — there is no
          // filesystem path to feed the pipeline.
          final bytes = await photo.readAsBytes();
          final path =
              '/picked/${DateTime.now().microsecondsSinceEpoch}/${photo.name}';
          WebFileStore.put(path, bytes);
          await _selectPaths([path]);
        } else {
          await _selectPaths([photo.path]);
        }
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
        _refresh(() => _loadingFiles = true);
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
        _refresh(() => _loadingFiles = true);
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
        // On web the picker can only hand back in-memory bytes — with
        // withData:false its "path" is a data URL that no File API can
        // open. On native a path is all we need, and withData:false keeps
        // large files out of memory twice.
        withData: kIsWeb,
        lockParentWindow: true,
      );

      if (result == null || result.files.isEmpty) {
        _addLog('File picker cancelled or no files selected.');
        return;
      }

      _addLog('Picked ${result.files.length} files via picker.');

      final List<String> validPaths;
      if (kIsWeb) {
        // The web engine has no virtual filesystem — dart:io file operations
        // throw in the browser — so the picked bytes are kept in memory,
        // keyed by synthetic paths the path-based pipeline can use. A unique
        // directory per batch avoids name collisions.
        final batchDir = '/picked/${DateTime.now().microsecondsSinceEpoch}';
        validPaths = [];
        final rejectedTooLarge = <String>[];
        for (final f in result.files) {
          final bytes = f.bytes;
          if (bytes == null) continue;
          // Web deployment limit: 10 MB per file.
          if (bytes.lengthInBytes > _webMaxFileSizeBytes) {
            rejectedTooLarge.add(f.name);
            continue;
          }
          final path = p.join(batchDir, f.name);
          WebFileStore.put(path, bytes);
          validPaths.add(path);
        }
        // Web deployment limit: 5 files per session (picks append to the
        // existing selection).
        final acceptedCount = validPaths.length;
        final room = _webMaxFiles - _selectedPaths.length;
        final keep = room.clamp(0, validPaths.length);
        if (validPaths.length > keep) {
          for (final path in validPaths.sublist(keep)) {
            WebFileStore.remove(path);
          }
          validPaths.removeRange(keep, validPaths.length);
        }
        if (rejectedTooLarge.isNotEmpty || acceptedCount > validPaths.length) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;
          final messenger = ScaffoldMessenger.of(context);
          if (rejectedTooLarge.isNotEmpty) {
            _addLog(
                'Rejected over-limit file(s): ${rejectedTooLarge.join(', ')}');
            messenger.showSnackBar(
              SnackBar(
                content:
                    Text(l10n.webFileTooLarge(rejectedTooLarge.join(', '))),
                duration: const Duration(seconds: 5),
              ),
            );
          }
          if (acceptedCount > validPaths.length) {
            _addLog('Rejected ${acceptedCount - validPaths.length} file(s) '
                'over the 5-file web limit.');
            messenger.showSnackBar(
              SnackBar(
                content: Text(room <= 0
                    ? l10n.webMaxFilesReached
                    : l10n.webFilesPartiallyAdded(
                        validPaths.length, acceptedCount)),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        validPaths = result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
      }

      if (validPaths.isNotEmpty) {
        _refresh(() => _loadingFiles = true);
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
      _refresh(() {
        _outputDirectory = directory;
      });
      _savePreference('outputDirectory', directory);
      _addLog('Auto-set output directory to: $directory');
    }

    _refresh(() {
      _selectedPaths = allPaths;
      _processedFiles = <ProcessedFile>[];
      _previewIndex = 0;
      _rawImage = null;
      _statusMessage = '';
    });

    // Web-only: (re)start the 2-minute in-memory retention window.
    _webStartRetentionWindow();

    try {
      if (allPaths.isNotEmpty) {
        final firstPath = allPaths.first;
        final extension = p.extension(firstPath).toLowerCase();
        if (['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
          // On web the source bytes live in the in-memory store (the
          // browser has no filesystem to read them from).
          final bytes = kIsWeb
              ? WebFileStore.bytesFor(firstPath)
              : await File(firstPath).readAsBytes();
          if (bytes != null) {
            final completer = Completer<ui.Image>();
            ui.decodeImageFromList(bytes, (image) {
              completer.complete(image);
            });
            final image = await completer.future;
            if (mounted) {
              _refresh(() {
                _rawImage = image;
              });
            }
          }
        }
      }
    } catch (e) {
      _addLog('Error reading first image for preview: $e');
      debugPrint('Preview error: $e');
    } finally {
      if (mounted) {
        _refresh(() {
          _loadingFiles = false;
        });
      }
    }
  }
}
