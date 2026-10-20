part of '../watermark_page.dart';

/// Configuration export/import (securemark_config.json) for [WatermarkPageState].

extension _WatermarkPageStateConfigBackupPart on WatermarkPageState {
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
        // Only export SecureMark related keys. The Ed25519 private key is
        // intentionally excluded: a backup must not carry the signing
        // identity's secret material.
        if (_isConfigBackupKey(key)) {
          configData[key] = prefs.get(key);
        }
      }

      final jsonConfig = jsonEncode(configData);
      final jsonBytes = utf8.encode(jsonConfig);
      _addLog('Exporting configuration with ${configData.length} keys...');

      final now = DateTime.now();
      final timestamp =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final String versionSuffix =
          _appVersion.isNotEmpty ? "_v$_appVersion" : "";
      final fileName = 'SecureMark_Backup${versionSuffix}_$timestamp.zip';

      // The web engine has no filesystem (and no temp directory) — build
      // the encrypted zip in memory and hand it to the browser as a
      // download.
      if (kIsWeb) {
        final archive = Archive();
        archive.addFile(
            ArchiveFile('securemark_config.json', jsonBytes.length, jsonBytes));
        final zipBytes = Uint8List.fromList(
            ZipEncoder(password: passwordController.text).encode(archive));
        browserDownload(zipBytes, fileName, 'application/zip');
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.configExportSuccess(fileName))),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final zipPath = p.join(tempDir.path, fileName);

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
        // On web the only usable result is the in-memory bytes.
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.single;
      if (pickedFile.path == null && pickedFile.bytes == null) return;

      if (!mounted) return;

      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.importConfigTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.importConfigPasswordHint),
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

      // On web the picked file exists only as in-memory bytes.
      final bytes = kIsWeb
          ? pickedFile.bytes!
          : await File(pickedFile.path!).readAsBytes();
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

            // Reject keys the export path would never produce so a malicious
            // backup zip cannot inject arbitrary SharedPreferences state
            // (e.g. device_private_key, https_cert_fingerprint).
            if (!_isConfigBackupKey(key)) {
              _addLog('Skipping non-config key from imported backup: $key');
              continue;
            }

            if (value is bool) {
              await prefs.setBool(key, value);
            } else if (value is num) {
              // On Web, JSON numbers decode as int even when the source had
              // a decimal point, so store by key type rather than runtime type.
              if (_isIntPreferenceKey(key)) {
                await prefs.setInt(key, value.toInt());
              } else {
                await prefs.setDouble(key, value.toDouble());
              }
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
        SnackBar(content: Text(l10n.importConfigFailed)),
      );
    }
  }
}
