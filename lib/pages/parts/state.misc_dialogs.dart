part of '../watermark_page.dart';

/// Logs, about, update checks, guides and identity dialogs.

extension _WatermarkPageStateMiscDialogsPart on WatermarkPageState {
  Future<void> _saveLogs() async {
    if (_logs.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final timestamp =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
    final fileName = "securemark_logs_$timestamp.txt";

    // The web engine has no filesystem (and no documents directory) —
    // hand the log to the browser as a download.
    if (kIsWeb) {
      final logContent = _logs.join('\n');
      browserDownload(
          Uint8List.fromList(utf8.encode(logContent)), fileName, 'text/plain');
      _addLog('Logs download started: $fileName');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.logsSaved(fileName)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Let the user choose a directory
    String? selectedDirectory;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        selectedDirectory = await FilePicker.platform.getDirectoryPath();
      } else {
        selectedDirectory = await getDirectoryPath();
      }
    } catch (e) {
      _addLog('Error selecting directory: $e');
    }

    String logPath;
    if (selectedDirectory != null) {
      // User selected a directory - save there
      logPath = p.join(selectedDirectory, fileName);
    } else {
      // User cancelled - save to default app documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      logPath = p.join(docsDir.path, fileName);
    }

    final logContent = _logs.join('\n');

    try {
      final File logFile = File(logPath);
      await logFile.writeAsString(logContent);
      _addLog('Logs saved to: $logPath');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.logsSaved(p.basename(logPath))),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _addLog('Error saving logs: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving logs: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
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
              // The log export is not part of the web UI (it would write
              // processing details to a downloaded file).
              if (!kIsWeb && _logs.isNotEmpty)
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
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.loadingIdentity),
                ],
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            _addLog('ERROR in Identity dialog: ${snapshot.error}');
            return AlertDialog(
              title: Text(l10n.myIdentityTitle),
              content: Text(l10n.identityLoadError('${snapshot.error}')),
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
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
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
                      // Share the self-describing identity-card URI so the
                      // receiver's app can import the key directly.
                      final card = ForensicUtils.generateIdentityCard(
                          _deviceNameController.text, publicKey, fingerprint);
                      SharePlus.instance.share(
                        ShareParams(
                          text: card,
                          subject: l10n.myIdentityTitle,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(l10n.sharePublicKey),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final card = ForensicUtils.generateIdentityCard(
                          _deviceNameController.text, publicKey, fingerprint);
                      _showQrIdentityDialog(card);
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
            Text(
              l10n.qrIdentityHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
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
