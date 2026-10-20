part of '../watermark_page.dart';

/// Peer-to-peer local sharing (HTTP server/client), QR exchange and encryption tasks.

// -------- Library-level declarations (kept private) --------

Uint8List _encryptBytesTask(Map<String, dynamic> params) {
  return EncryptionUtils.encryptBytes(params['data'], params['key']);
}

Uint8List? _decryptBytesTask(Map<String, dynamic> params) {
  return EncryptionUtils.decryptBytes(params['data'], params['key']);
}

/// A QR identity payload carries a Base64-encoded Ed25519 public key.
/// Accept only keys that decode to exactly 32 bytes so corrupt or
/// attacker-crafted values never reach the bookmark list (and later
/// signature verification).
bool _isValidEd25519PublicKey(String encoded) {
  final normalized = encoded.trim();
  if (normalized.isEmpty) return false;
  final Uint8List? decoded;
  try {
    decoded = base64Decode(normalized);
  } catch (_) {
    return false;
  }
  return decoded.length == 32;
}

extension _WatermarkPageStateLocalSharePart on WatermarkPageState {
  void _showLocalShareDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Get network interfaces with internal/external classification
    _networkInterfaces = await LocalServerManager.getNetworkInterfaces();
    _selectedInterfaceIndex = 0;

    // Log detected interfaces
    _addLog('📡 Detected ${_networkInterfaces.length} network interfaces:');
    for (var i = 0; i < _networkInterfaces.length; i++) {
      final iface = _networkInterfaces[i];
      _addLog(
          '  [$i] ${iface.ipAddress} (${iface.interfaceName}) - ${iface.isExternal ? "External" : "Internal"}');
    }
    if (_networkInterfaces.isNotEmpty) {
      _addLog(
          '✓ Default selected: ${_networkInterfaces[0].ipAddress} (${_networkInterfaces[0].interfaceName})');
    }

    if (!mounted) return;

    // Responsive sizing: larger on mobile but still as dialog (to preserve log visibility)
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    final dialogWidth = isMobile ? screenWidth * 0.95 : 700.0;
    final dialogHeight = isMobile ? screenHeight * 0.80 : 600.0;

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
                    Expanded(child: Text(l10n.localShareTitle)),
                  ],
                ),
                content: SizedBox(
                  width: dialogWidth,
                  height: dialogHeight,
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
                      _refresh(() {
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
                  : const Text(
                      '⚠️ Large encrypted files (>500 MB) may cause Out of Memory on download',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
              secondary: Icon(Icons.enhanced_encryption_outlined,
                  size: 20,
                  color: _useLocalEncryption
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              value: _useLocalEncryption,
              onChanged: (val) {
                setDialogState(() => _useLocalEncryption = val);
              },
            ),
            // HTTPS Toggle
            SwitchListTile(
              title: Text(l10n.useHttpsTitle,
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                _useHttps ? l10n.useHttpsSubtitleOn : l10n.useHttpsSubtitleOff,
                style: TextStyle(
                  fontSize: 11,
                  color: _useHttps ? Colors.green : Colors.grey,
                ),
              ),
              secondary: Icon(
                _useHttps ? Icons.https : Icons.http,
                size: 20,
                color: _useHttps
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              value: _useHttps,
              onChanged: (val) async {
                if (val) {
                  // Enable HTTPS: Always generate fresh certificate
                  try {
                    setDialogState(() {
                      _addLog('Generating fresh self-signed certificate...');
                    });

                    // Delete old certificate if it exists
                    await CertificateManager.deleteCertificate();

                    // Generate new certificate
                    await CertificateManager.generateCertificate();
                    final fingerprint =
                        await CertificateManager.getFingerprint();

                    // Update both dialog state AND main widget state
                    if (mounted) {
                      _refresh(() {
                        _certificateFingerprint = fingerprint;
                        _useHttps = true;
                      });
                    }
                    setDialogState(() {
                      _certificateFingerprint = fingerprint;
                      _useHttps = true;
                      _addLog('✅ Certificate generated successfully');
                      _addLog('📋 Fingerprint: ${fingerprint ?? "NULL"}');
                    });
                  } catch (e) {
                    setDialogState(() {
                      _addLog('❌ Failed to generate certificate: $e');
                      _addLog('💡 Install OpenSSL or use HTTP mode');
                      _useHttps = false;
                    });
                    if (mounted) {
                      _refresh(() {
                        _useHttps = false;
                        _certificateFingerprint = null;
                      });
                    }
                    return;
                  }
                } else {
                  // Disable HTTPS - delete certificate and clear state
                  await CertificateManager.deleteCertificate();

                  if (mounted) {
                    _refresh(() {
                      _useHttps = false;
                      _certificateFingerprint = null;
                    });
                  }
                  setDialogState(() {
                    _useHttps = false;
                    _certificateFingerprint = null;
                    _addLog('🗑️ HTTPS disabled, certificate deleted');
                  });
                }
              },
            ),
            // Push to Receiver Toggle
            SwitchListTile(
              title: Text(l10n.pushToReceiverTitle,
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text(l10n.pushToReceiverSubtitle,
                  style: const TextStyle(fontSize: 11)),
              secondary: const Icon(Icons.qr_code_scanner, size: 20),
              value: _pushToReceiver,
              onChanged: (val) {
                setDialogState(() => _pushToReceiver = val);
              },
            ),
            const Divider(),

            // Network Interface Selection
            if (!_pushToReceiver && _networkInterfaces.isNotEmpty) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.networkInterfaceLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: _selectedInterfaceIndex,
                      isExpanded: true,
                      items: List.generate(
                        _networkInterfaces.length,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Row(
                            children: [
                              Icon(
                                _networkInterfaces[i].isExternal
                                    ? Icons.public
                                    : Icons.home_outlined,
                                size: 18,
                                color: _networkInterfaces[i].isExternal
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _networkInterfaces[i].ipAddress,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _networkInterfaces[i].isExternal
                                    ? 'External'
                                    : 'Internal',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _networkInterfaces[i].isExternal
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedInterfaceIndex = value!;
                          _addLog(
                              'Selected interface: ${_networkInterfaces[value].ipAddress}');
                        });
                      },
                    ),
                    if (_networkInterfaces[_selectedInterfaceIndex].isExternal)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Warning: External IP detected! May be accessible from internet.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
            ],

            // Pick Custom File Button
            ListTile(
              title: Text(l10n.pickAnyFile,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.file_open_outlined),
              onTap: () async {
                final result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  final filePath = result.files.single.path!;
                  final fileName = result.files.single.name;

                  if (_pushToReceiver || _useLocalEncryption) {
                    // Need bytes in memory for push or encryption
                    final bytes = await File(filePath).readAsBytes();
                    if (_pushToReceiver) {
                      _showPushQrScanner(bytes: bytes, fileName: fileName);
                    } else {
                      await _startServingEncrypted(
                          bytes, fileName, setDialogState,
                          filePath: filePath);
                    }
                  } else {
                    // Unencrypted: Stream from file (memory-efficient!)
                    await _startServingEncrypted(null, fileName, setDialogState,
                        filePath: filePath);
                  }
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
                    if (_pushToReceiver) {
                      _showPushQrScanner(bytes: bytes, fileName: fileName);
                    } else {
                      await _startServingEncrypted(
                          bytes, fileName, setDialogState);
                    }
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
                      if (_pushToReceiver) {
                        // Push mode needs bytes in memory
                        final bytes = file.result.outputBytes;
                        _showPushQrScanner(bytes: bytes, fileName: fileName);
                      } else if (_useLocalEncryption) {
                        // Encryption needs bytes in memory
                        final bytes = file.result.outputBytes;
                        await _startServingEncrypted(
                          bytes,
                          fileName,
                          setDialogState,
                          filePath: file.result.outputPath,
                        );
                      } else {
                        // Unencrypted: Stream from file (memory-efficient!)
                        await _startServingEncrypted(
                          null, // No bytes - will use filePath instead
                          fileName,
                          setDialogState,
                          filePath: file.result.outputPath,
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ] else ...[
            Text(l10n.sendingFile(_sendingFileName ?? '')),
            const SizedBox(height: 8),
            // Network interface selection with internal/external indicator
            if (_networkInterfaces.length > 1)
              DropdownButton<int>(
                value: _selectedInterfaceIndex,
                isExpanded: true,
                items: List.generate(
                    _networkInterfaces.length,
                    (i) => DropdownMenuItem(
                          value: i,
                          child: Row(
                            children: [
                              Icon(
                                _networkInterfaces[i].isExternal
                                    ? Icons.public
                                    : Icons.home_outlined,
                                size: 16,
                                color: _networkInterfaces[i].isExternal
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _networkInterfaces[i].ipAddress,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                _networkInterfaces[i].isExternal
                                    ? 'External'
                                    : 'Internal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _networkInterfaces[i].isExternal
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        )),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => _selectedInterfaceIndex = val);
                  }
                },
              )
            else if (_networkInterfaces.isNotEmpty)
              Row(
                children: [
                  Icon(
                    _networkInterfaces.first.isExternal
                        ? Icons.public
                        : Icons.home_outlined,
                    size: 16,
                    color: _networkInterfaces.first.isExternal
                        ? Colors.orange
                        : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _networkInterfaces.first.ipAddress,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _networkInterfaces.first.isExternal
                        ? '(External)'
                        : '(Internal)',
                    style: TextStyle(
                      fontSize: 11,
                      color: _networkInterfaces.first.isExternal
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: () {
                  final protocol = _useHttps ? 'https' : 'http';
                  final ip =
                      _networkInterfaces[_selectedInterfaceIndex].ipAddress;
                  final baseUrl =
                      '$protocol://$ip:$_servingPort/${LocalServerManager.token}/download';

                  // Add encryption key if present
                  final urlWithKey = _localEncryptionKey != null
                      ? '$baseUrl?key=$_localEncryptionKey'
                      : baseUrl;

                  // Add fingerprint fragment for HTTPS
                  final finalUrl = _useHttps && _certificateFingerprint != null
                      ? '$urlWithKey#fp=$_certificateFingerprint'
                      : urlWithKey;

                  return finalUrl;
                }(),
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 8),
            // Certificate fingerprint display (HTTPS only)
            if (_useHttps && _certificateFingerprint != null) ...[
              const Text(
                'Certificate Fingerprint (SHA-256):',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _certificateFingerprint!,
                style: const TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Verify this matches on receiver',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            // Progress display (only shown during active transfer)
            if (_transferTotal > 0) ...[
              LinearProgressIndicator(
                value: _transferProgress / _transferTotal,
              ),
              const SizedBox(height: 8),
              Text(
                'Uploading: ${(_transferProgress / (1024 * 1024)).toStringAsFixed(1)} / ${(_transferTotal / (1024 * 1024)).toStringAsFixed(1)} MB (${((_transferProgress / _transferTotal) * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await LocalServerManager.cancelTransfer();
                    setDialogState(() {
                      _servingPort = 0;
                      _sendingFileName = null;
                      _transferProgress = 0;
                      _transferTotal = 0;
                    });
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await LocalServerManager.stopServer();
                    setDialogState(() {
                      _servingPort = 0;
                      _sendingFileName = null;
                      _transferProgress = 0;
                      _transferTotal = 0;
                    });
                  },
                  icon: const Icon(Icons.stop),
                  label: Text(l10n.reset),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiveTab(StateSetter setDialogState) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

    // Auto-prompt for writable directory on mobile if not set
    if (isMobile && _outputDirectory == null && !_hasPromptedForMobileDir) {
      _hasPromptedForMobileDir = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _pickOutputDirectory();
        if (mounted) setDialogState(() {});
      });
    }

    if (_showReceiveQr) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(l10n.waitingForFile,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_networkInterfaces.length > 1)
            DropdownButton<int>(
              value: _selectedInterfaceIndex,
              isExpanded: true,
              items: List.generate(
                  _networkInterfaces.length,
                  (i) => DropdownMenuItem(
                        value: i,
                        child: Row(
                          children: [
                            Icon(
                              _networkInterfaces[i].isExternal
                                  ? Icons.public
                                  : Icons.home_outlined,
                              size: 16,
                              color: _networkInterfaces[i].isExternal
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(_networkInterfaces[i].ipAddress),
                          ],
                        ),
                      )),
              onChanged: (val) {
                if (val != null) {
                  setDialogState(() => _selectedInterfaceIndex = val);
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
                  'securemark://receive?addr=${_networkInterfaces[_selectedInterfaceIndex].ipAddress}&port=$_servingPort&token=${LocalServerManager.token}',
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
            label: Text(l10n.backToCamera),
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
            child: !kIsWeb && (Platform.isLinux || Platform.isWindows)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            size: 48, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            l10n.qrScanningUnsupportedUseShowQr(
                                Platform.isLinux ? 'Linux' : 'Windows'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                : MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final String? code = barcodes.first.rawValue;
                        if (code != null &&
                            code.startsWith('http') &&
                            code.contains('/download')) {
                          Navigator.pop(context);
                          _downloadFromLocalUrl(code);
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

        // Network Interface Selection (before starting server)
        if (_networkInterfaces.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.networkInterfaceLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<int>(
                  value: _selectedInterfaceIndex,
                  isExpanded: true,
                  items: List.generate(
                    _networkInterfaces.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Row(
                        children: [
                          Icon(
                            _networkInterfaces[i].isExternal
                                ? Icons.public
                                : Icons.home_outlined,
                            size: 18,
                            color: _networkInterfaces[i].isExternal
                                ? Colors.orange
                                : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _networkInterfaces[i].ipAddress,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _networkInterfaces[i].isExternal
                                ? 'External'
                                : 'Internal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _networkInterfaces[i].isExternal
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedInterfaceIndex = value!;
                      _addLog(
                          'Selected interface: ${_networkInterfaces[value].ipAddress}');
                    });
                  },
                ),
                if (_networkInterfaces[_selectedInterfaceIndex].isExternal)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Warning: External IP detected! May be accessible from internet.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text(l10n.localShareInstructions, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final port = await LocalServerManager.startReceiveServer(
                (fileName, remoteAddr, {String? filePath}) {
              try {
                _addLog('Received file $fileName from $remoteAddr');

                if (filePath == null) {
                  _addLog('❌ Error: Cannot save file - no file path provided');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: File transfer failed'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                  return;
                }

                // Use memory-efficient file path (no reloading into memory!)
                _saveDownloadedFile(
                  null, // No bytes - using file path instead
                  fileName,
                  l10n: l10n,
                  sourceFilePath: filePath,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.fileReceived(remoteAddr))),
                  );
                }

                // Run a background integrity check on the received file;
                // the result appears as a badge with a tap-to-open details
                // card. Never blocks the receive flow.
                _autoVerifyReceivedFile(filePath, fileName);
              } catch (e, stackTrace) {
                _addLog('❌ Error handling received file: $e');
                _addLog('Stack trace: $stackTrace');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving file: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            }, onDone: () {
              if (mounted) {
                setDialogState(() {
                  _servingPort = 0;
                  _showReceiveQr = false;
                });
              }
            },
                bindAddress: _networkInterfaces.isNotEmpty
                    ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
                    : null);

            // Add detailed logging for debugging
            final selectedIp = _networkInterfaces.isNotEmpty
                ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
                : 'unknown';
            _addLog('📡 Receive server listening on: $selectedIp:$port');
            _addLog(
                '🔗 Upload endpoint: http://$selectedIp:$port/upload (token in Authorization header)');

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

  Future<void> _handleReversePush(String qrData,
      {Uint8List? pushBytes, String? pushFileName}) async {
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

    // 1. Pick file to send (if not already provided)
    Uint8List? fileBytes = pushBytes;
    String? fileName = pushFileName;

    if (fileBytes == null || fileName == null) {
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
      // Send the token in the Authorization header rather than in the URL so
      // the secret is not exposed in request logs.
      final uploadUrl = 'http://$addr:$port/upload';
      final request = http.Request('POST', Uri.parse(uploadUrl));
      request.headers['x-file-name'] = fileName;
      request.headers['authorization'] = 'Bearer $token';
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

  /// Start serving file - supports both bytes and file path for streaming
  Future<void> _startServingEncrypted(
      Uint8List? bytes, String fileName, StateSetter setDialogState,
      {String? filePath}) async {
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
        if (bytes == null) {
          throw ArgumentError(
              'Encryption requires bytes in memory (cannot stream from file)');
        }

        // Check file size and warn about large encrypted files
        final fileSizeMB = bytes.length / (1024 * 1024);
        if (fileSizeMB > 500) {
          addLog(
              '⚠️ Warning: Encrypting large file (${fileSizeMB.toStringAsFixed(1)} MB)');
          addLog(
              '   Large encrypted files may cause Out of Memory on receiver!');
          addLog('   Consider disabling encryption for files >500 MB.');
          _addLog(
              '⚠️ Encrypting ${fileSizeMB.toStringAsFixed(1)} MB file - may cause OOM on download!');
        }

        addLog(l10n.generatingKey);
        // Generate separate encryption key (independent from URL access token)
        final key = LocalServerManager.generateEncryptionKey();
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

        // Load certificate fingerprint for HTTPS before starting server
        if (_useHttps) {
          addLog('Loading certificate fingerprint...');
          _certificateFingerprint = await CertificateManager.getFingerprint();
          addLog(
              'Certificate fingerprint: ${_certificateFingerprint ?? "NULL"}');
          if (_certificateFingerprint == null) {
            throw Exception(
                'HTTPS enabled but certificate fingerprint not available');
          }
        }

        addLog(l10n.startingServer);

        // Throttle progress updates to avoid excessive UI rebuilds
        var lastProgressUpdate = DateTime.now();
        const progressUpdateInterval = Duration(milliseconds: 100);

        final port = _useHttps
            ? await LocalServerManager.startServerSecure(
                encryptedBytes,
                fileName,
                bindAddress: _networkInterfaces.isNotEmpty
                    ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
                    : null,
                onProgress: (sent, total) {
                  final now = DateTime.now();
                  if (now.difference(lastProgressUpdate) >=
                      progressUpdateInterval) {
                    lastProgressUpdate = now;
                    setDialogState(() {
                      _transferProgress = sent;
                      _transferTotal = total;
                    });
                  }
                },
                onDone: () {
                  if (mounted) {
                    setDialogState(() {
                      _servingPort = 0;
                      _sendingFileName = null;
                      _transferProgress = 0;
                      _transferTotal = 0;
                    });
                  }
                },
              )
            : await LocalServerManager.startServer(
                encryptedBytes,
                fileName,
                bindAddress: _networkInterfaces.isNotEmpty
                    ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
                    : null,
                onProgress: (sent, total) {
                  final now = DateTime.now();
                  if (now.difference(lastProgressUpdate) >=
                      progressUpdateInterval) {
                    lastProgressUpdate = now;
                    setDialogState(() {
                      _transferProgress = sent;
                      _transferTotal = total;
                    });
                  }
                },
                onDone: () {
                  if (mounted) {
                    setDialogState(() {
                      _servingPort = 0;
                      _sendingFileName = null;
                      _transferProgress = 0;
                      _transferTotal = 0;
                    });
                  }
                },
              );
        await Future.delayed(const Duration(milliseconds: 500));
        progress = 1.0;
        addLog(l10n.serverStarted(port));

        // Add detailed logging for debugging
        final selectedIp = _networkInterfaces.isNotEmpty
            ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
            : 'unknown';
        final protocol = _useHttps ? 'https' : 'http';
        _addLog(
            '📡 Server listening on: $selectedIp:$port (${_useHttps ? "HTTPS" : "HTTP"})');
        final baseUrl =
            '$protocol://$selectedIp:$port/${LocalServerManager.token}/download';
        final urlWithKey = _localEncryptionKey != null
            ? '$baseUrl?key=$_localEncryptionKey'
            : baseUrl;
        final finalUrl = _useHttps && _certificateFingerprint != null
            ? '$urlWithKey#fp=$_certificateFingerprint'
            : urlWithKey;
        _addLog('🔗 Access URL: $finalUrl');
        if (_useHttps && _certificateFingerprint != null) {
          _addLog('🔒 Certificate fingerprint included in URL');
        } else if (_useHttps && _certificateFingerprint == null) {
          _addLog('⚠️ HTTPS enabled but fingerprint is NULL');
        }

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        setDialogState(() {
          _servingPort = port;
          _sendingFileName = fileName;
        });
      } else {
        _localEncryptionKey = null;

        // Load certificate fingerprint for HTTPS before starting server
        if (_useHttps) {
          addLog('Loading certificate fingerprint...');
          _certificateFingerprint = await CertificateManager.getFingerprint();
          addLog(
              'Certificate fingerprint: ${_certificateFingerprint ?? "NULL"}');
          if (_certificateFingerprint == null) {
            throw Exception(
                'HTTPS enabled but certificate fingerprint not available');
          }
        }

        addLog(l10n.startingServer);

        // Throttle progress updates to avoid excessive UI rebuilds
        var lastProgressUpdate = DateTime.now();
        const progressUpdateInterval = Duration(milliseconds: 100);

        // Use streaming from file path if available (memory-efficient)
        final int port;
        if (filePath != null && await File(filePath).exists()) {
          addLog('Using streaming transfer (memory-efficient)');
          port = _useHttps
              ? await LocalServerManager.startServerFromFileSecure(
                  filePath,
                  bindAddress: _networkInterfaces.isNotEmpty
                      ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
                      : null,
                  onProgress: (sent, total) {
                    final now = DateTime.now();
                    if (now.difference(lastProgressUpdate) >=
                        progressUpdateInterval) {
                      lastProgressUpdate = now;
                      setDialogState(() {
                        _transferProgress = sent;
                        _transferTotal = total;
                      });
                    }
                  },
                  onDone: () {
                    if (mounted) {
                      setDialogState(() {
                        _servingPort = 0;
                        _sendingFileName = null;
                        _transferProgress = 0;
                        _transferTotal = 0;
                      });
                    }
                  },
                )
              : await LocalServerManager.startServerFromFile(
                  filePath,
                  bindAddress: _networkInterfaces.isNotEmpty
                      ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
                      : null,
                  onProgress: (sent, total) {
                    final now = DateTime.now();
                    if (now.difference(lastProgressUpdate) >=
                        progressUpdateInterval) {
                      lastProgressUpdate = now;
                      setDialogState(() {
                        _transferProgress = sent;
                        _transferTotal = total;
                      });
                    }
                  },
                  onDone: () {
                    if (mounted) {
                      setDialogState(() {
                        _servingPort = 0;
                        _sendingFileName = null;
                        _transferProgress = 0;
                        _transferTotal = 0;
                      });
                    }
                  },
                );
        } else if (bytes != null) {
          // Fallback to in-memory transfer
          addLog(
              'Using in-memory transfer (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB)');
          port = _useHttps
              ? await LocalServerManager.startServerSecure(
                  bytes,
                  fileName,
                  bindAddress: _networkInterfaces.isNotEmpty
                      ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
                      : null,
                  onProgress: (sent, total) {
                    final now = DateTime.now();
                    if (now.difference(lastProgressUpdate) >=
                        progressUpdateInterval) {
                      lastProgressUpdate = now;
                      setDialogState(() {
                        _transferProgress = sent;
                        _transferTotal = total;
                      });
                    }
                  },
                  onDone: () {
                    if (mounted) {
                      setDialogState(() {
                        _servingPort = 0;
                        _sendingFileName = null;
                        _transferProgress = 0;
                        _transferTotal = 0;
                      });
                    }
                  },
                )
              : await LocalServerManager.startServer(
                  bytes,
                  fileName,
                  bindAddress: _networkInterfaces.isNotEmpty
                      ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
                      : null,
                  onProgress: (sent, total) {
                    final now = DateTime.now();
                    if (now.difference(lastProgressUpdate) >=
                        progressUpdateInterval) {
                      lastProgressUpdate = now;
                      setDialogState(() {
                        _transferProgress = sent;
                        _transferTotal = total;
                      });
                    }
                  },
                  onDone: () {
                    if (mounted) {
                      setDialogState(() {
                        _servingPort = 0;
                        _sendingFileName = null;
                        _transferProgress = 0;
                        _transferTotal = 0;
                      });
                    }
                  },
                );
        } else {
          throw ArgumentError(
              'Either bytes or filePath must be provided for unencrypted transfer');
        }

        progress = 1.0;
        addLog(l10n.serverStarted(port));

        // Add detailed logging for debugging
        final selectedIp = _networkInterfaces.isNotEmpty
            ? _networkInterfaces[_selectedInterfaceIndex].ipAddress
            : 'unknown';
        final protocol = _useHttps ? 'https' : 'http';
        _addLog(
            '📡 Server listening on: $selectedIp:$port (${_useHttps ? "HTTPS" : "HTTP"})');
        final baseUrl =
            '$protocol://$selectedIp:$port/${LocalServerManager.token}/download';
        final urlWithKey = _localEncryptionKey != null
            ? '$baseUrl?key=$_localEncryptionKey'
            : baseUrl;
        final finalUrl = _useHttps && _certificateFingerprint != null
            ? '$urlWithKey#fp=$_certificateFingerprint'
            : urlWithKey;
        _addLog('🔗 Access URL: $finalUrl');
        if (_useHttps && _certificateFingerprint != null) {
          _addLog('🔒 Certificate fingerprint included in URL');
        } else if (_useHttps && _certificateFingerprint == null) {
          _addLog('⚠️ HTTPS enabled but fingerprint is NULL');
        }

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

  /// Send acknowledgment to server that file was received successfully
  Future<void> _sendDownloadAcknowledgment(
      Uri downloadUri, HttpClient? httpsClient) async {
    try {
      // Build ack URL from download URL
      final ackUri = Uri(
        scheme: downloadUri.scheme,
        host: downloadUri.host,
        port: downloadUri.port,
        path: downloadUri.path.replaceAll('/download', '/ack'),
      );

      _addLog('Sending acknowledgment to server: ${ackUri.path}');

      if (httpsClient != null) {
        // Use same HTTPS client (with certificate callback)
        final req = await httpsClient.getUrl(ackUri);
        final resp = await req.close().timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          _addLog('✅ Server acknowledged receipt confirmation');
        }
        // Drain response stream
        await resp.drain();
      } else {
        // Use regular HTTP client
        final response =
            await http.get(ackUri).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _addLog('✅ Server acknowledged receipt confirmation');
        }
      }
    } catch (e) {
      // Don't fail the download if ack fails
      _addLog('⚠️ Failed to send acknowledgment (server may timeout): $e');
    }
  }

  Future<void> _downloadFromLocalUrl(String url) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    List<String> progressLogs = [];
    double progressValue = 0.0;
    String speedText = '';
    HttpClient? httpClient; // Declare early so cancel button can access it

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
              actions: [
                TextButton(
                  onPressed: () {
                    _stopStopwatch();
                    _progressListener = null;
                    Navigator.of(context, rootNavigator: true).pop();
                    _addLog('❌ Download cancelled by user');
                  },
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );

    try {
      final uri = Uri.parse(url);
      final key = uri.queryParameters['key'];
      final isHttps = uri.scheme == 'https';

      // Extract fingerprint from URL fragment (#fp=...)
      String? expectedFingerprint;
      addLog('URL scheme: ${uri.scheme}');
      addLog('URL fragment: "${uri.fragment}"');
      if (uri.fragment.isNotEmpty) {
        final fragmentParts = uri.fragment.split('=');
        addLog(
            'Fragment parts: ${fragmentParts.length} - ${fragmentParts.join(" | ")}');
        if (fragmentParts.length == 2 && fragmentParts[0] == 'fp') {
          expectedFingerprint = fragmentParts[1];
          final preview = expectedFingerprint.length > 30
              ? '${expectedFingerprint.substring(0, 30)}...'
              : expectedFingerprint;
          addLog('✅ Extracted fingerprint: $preview');
        } else {
          addLog('❌ Fragment format invalid (expected fp=...)');
        }
      } else {
        addLog('⚠️ No fragment in URL (no fingerprint)');
      }

      // HTTPS with fingerprint: Show verification dialog first
      if (isHttps && expectedFingerprint != null) {
        addLog('📋 HTTPS with fingerprint - showing verification dialog');
        // Close progress dialog temporarily
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Verify Certificate'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This server uses HTTPS with a self-signed certificate.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Expected fingerprint (from QR code):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  expectedFingerprint ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The actual certificate fingerprint will be verified automatically during download.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Does the fingerprint above match what is displayed on the sender?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: const Text('Trust & Download'),
              ),
            ],
          ),
        );

        if (verified != true) {
          _stopStopwatch();
          _addLog('❌ Certificate verification cancelled by user');
          return;
        }

        // Check if widget is still mounted before using context
        if (!mounted) return;

        // Re-show progress dialog after verification
        _elapsedTime = '00:00';
        _startStopwatch();
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
                  actions: [
                    TextButton(
                      onPressed: () {
                        // Cancel download
                        httpClient?.close(force: true);
                        _stopStopwatch();
                        _progressListener = null;
                        Navigator.of(context, rootNavigator: true).pop();
                        _addLog('❌ Download cancelled by user');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Download cancelled'),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      },
                      child: Text(l10n.cancel),
                    ),
                  ],
                );
              },
            );
          },
        );
      }

      addLog(
          'Connecting to: ${uri.host}:${uri.port}${uri.path} (${isHttps ? "HTTPS" : "HTTP"})');
      addLog(l10n.connectingToServer);

      // Use different client based on HTTPS with fingerprint verification
      final http.StreamedResponse response;

      if (isHttps && expectedFingerprint != null) {
        // HTTPS with certificate fingerprint verification
        addLog('Using HTTPS with certificate fingerprint verification');
        httpClient = HttpClient();

        // CRITICAL: This callback must accept self-signed certificates
        // PERFORMANCE: Cache verification result and minimize logging to avoid slowdown
        // Capture expectedFingerprint in local variable for closure
        final expectedFp = expectedFingerprint;
        bool? cachedVerificationResult;

        httpClient.badCertificateCallback = (cert, host, port) {
          try {
            // Return cached result if already verified (callback may be invoked multiple times)
            final cached = cachedVerificationResult;
            if (cached != null) {
              return cached;
            }

            // Calculate actual fingerprint (only once)
            final der = cert.der;
            final digest = sha256.convert(der);
            final actualFingerprint = digest.bytes
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(':')
                .toUpperCase();

            // Verify fingerprint matches
            final matches = actualFingerprint == expectedFp;
            cachedVerificationResult = matches;

            // Log result asynchronously (only once, without blocking TLS handshake)
            Future.microtask(() {
              if (matches) {
                _addLog('✅ Certificate verified (fingerprints match)');
              } else {
                _addLog('❌ Certificate REJECTED (fingerprint mismatch)');
                _addLog('   Expected: $expectedFp');
                _addLog('   Actual:   $actualFingerprint');
              }
            });

            return matches;
          } catch (e) {
            // Log error asynchronously to avoid blocking
            Future.microtask(
                () => _addLog('❌ Certificate verification error: $e'));
            return false;
          }
        };

        addLog('Connecting to HTTPS server: ${uri.host}:${uri.port}');

        final HttpClientRequest req;
        final HttpClientResponse resp;

        try {
          req = await httpClient.getUrl(uri);
          addLog('Request created successfully');
          resp = await req.close().timeout(const Duration(seconds: 30));
          addLog('Response received with status: ${resp.statusCode}');
        } catch (e) {
          addLog('❌ Error during HTTPS connection: $e');
          _addLog('❌ HTTPS connection failed: $e');
          _addLog(
              '   This usually means badCertificateCallback was not called or returned false');
          rethrow;
        }

        // Convert HttpClientResponse to StreamedResponse
        final headers = <String, String>{};
        resp.headers.forEach((name, values) {
          headers[name] = values.join(', ');
        });

        response = http.StreamedResponse(
          resp,
          resp.statusCode,
          contentLength: resp.contentLength,
          headers: headers,
        );
      } else if (isHttps) {
        // HTTPS without a fingerprint: refuse to proceed. Accepting an
        // unverifiable self-signed certificate would defeat MITM protection.
        const error =
            'HTTPS download requires a certificate fingerprint for verification.';
        addLog(error);
        throw Exception(error);
      } else {
        // Regular HTTP
        final client = http.Client();
        final request = http.Request('GET', uri);
        response =
            await client.send(request).timeout(const Duration(seconds: 30));
      }

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        final startTime = DateTime.now();

        addLog(l10n.downloadingFile(''));

        // Get filename early
        String fileName = 'downloaded_file';
        final disp = response.headers['content-disposition'];
        if (disp != null && disp.contains('filename=')) {
          fileName = disp.split('filename=').last.replaceAll('"', '');
        } else {
          fileName = p.basename(uri.path);
          if (fileName == 'download') fileName = 'securemark_file';
        }
        // The name is server-controlled (or from a URL) and is joined into a
        // filesystem path below; reduce it to a safe basename first.
        fileName = WatermarkUtils.sanitizeFileName(fileName);

        // Check if encrypted (needs in-memory processing)
        final isEncrypted = key != null;

        // Throttle progress updates to avoid excessive UI rebuilds
        var lastProgressUpdate = DateTime.now();
        const progressUpdateInterval = Duration(milliseconds: 100);

        if (isEncrypted) {
          // Encrypted: Must load into memory for HMAC verification & decryption
          addLog(
              'Downloading encrypted file (${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)...');
          final BytesBuilder builder = BytesBuilder();

          await for (final chunk in response.stream) {
            builder.add(chunk);
            receivedBytes += chunk.length;

            final now = DateTime.now();
            final duration = now.difference(startTime).inMilliseconds / 1000.0;
            if (duration > 0) {
              final speed =
                  (receivedBytes / 1024.0 / 1024.0) / duration; // MB/s
              speedText = '${speed.toStringAsFixed(2)} MB/s';
            }

            if (totalBytes > 0) {
              progressValue =
                  (receivedBytes / totalBytes * 0.7).clamp(0.0, 0.7);
            }

            // Only update UI every 100ms to avoid excessive rebuilds
            if (now.difference(lastProgressUpdate) >= progressUpdateInterval) {
              lastProgressUpdate = now;
              _progressListener?.call();
            }
          }

          // Final update to ensure 100% is shown
          _progressListener?.call();

          final bytes = builder.toBytes();
          addLog(l10n.connectionEstablished);

          addLog(l10n.decryptingPayload);
          progressValue = 0.75;
          _progressListener?.call();

          // Use compute for decryption
          final decrypted =
              await compute(_decryptBytesTask, {'data': bytes, 'key': key});
          if (decrypted == null) {
            throw Exception('Decryption failed. Wrong key or corrupted data.');
          }

          progressValue = 1.0;
          _progressListener?.call();

          _stopStopwatch();
          _progressListener = null;
          if (mounted) Navigator.of(context, rootNavigator: true).pop();

          await _saveDownloadedFile(decrypted, fileName, l10n: l10n);

          // Send acknowledgment to server that file was received successfully
          await _sendDownloadAcknowledgment(uri, httpClient);
        } else {
          // Unencrypted: Stream directly to file (memory-efficient!)
          addLog(
              'Streaming to disk (${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)...');

          // Create temp file for streaming
          final tempDir = await Directory.systemTemp.createTemp('download_');
          final tempFile = File(p.join(tempDir.path, fileName));
          final sink = tempFile.openWrite();

          try {
            await for (final chunk in response.stream) {
              sink.add(chunk);
              receivedBytes += chunk.length;

              final now = DateTime.now();
              final duration =
                  now.difference(startTime).inMilliseconds / 1000.0;
              if (duration > 0) {
                final speed =
                    (receivedBytes / 1024.0 / 1024.0) / duration; // MB/s
                speedText = '${speed.toStringAsFixed(2)} MB/s';
              }

              if (totalBytes > 0) {
                progressValue = (receivedBytes / totalBytes).clamp(0.0, 1.0);
              }

              // Only update UI every 100ms to avoid excessive rebuilds
              if (now.difference(lastProgressUpdate) >=
                  progressUpdateInterval) {
                lastProgressUpdate = now;
                _progressListener?.call();
              }
            }

            // Final update to ensure 100% is shown
            _progressListener?.call();

            await sink.flush();
            await sink.close();

            addLog(l10n.connectionEstablished);

            _stopStopwatch();
            _progressListener = null;
            if (mounted) Navigator.of(context, rootNavigator: true).pop();

            // Save using file path (memory-efficient - no reloading!)
            await _saveDownloadedFile(
              null,
              fileName,
              l10n: l10n,
              sourceFilePath: tempFile.path,
            );

            // Send acknowledgment to server that file was received successfully
            await _sendDownloadAcknowledgment(uri, httpClient);

            // Cleanup temp
            await tempDir.delete(recursive: true);
          } catch (e) {
            await sink.close();
            await tempDir.delete(recursive: true);
            rethrow;
          }
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      _stopStopwatch();
      _progressListener = null;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      final uri = Uri.tryParse(url);
      _addLog('❌ Download failed: $e');
      if (uri != null) {
        _addLog('   Target: ${uri.host}:${uri.port}');
        _addLog('   Path: ${uri.path}');
      }
      _addLog('   Error type: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: theme.colorScheme.error),
        );
      }
    } finally {
      // Clean up HTTPS client if used
      httpClient?.close();
    }
  }

  /// Save downloaded file - accepts either bytes or a file path for memory efficiency
  Future<void> _saveDownloadedFile(Uint8List? bytes, String fileName,
      {AppLocalizations? l10n, String? sourceFilePath}) async {
    final effectiveL10n = l10n ?? AppLocalizations.of(context)!;
    // Never trust a caller-supplied name for filesystem or picker use; reduce
    // it to a bare basename so it cannot traverse out of the target directory.
    fileName = WatermarkUtils.sanitizeFileName(fileName);

    final String? outDir = _outputDirectory;
    if (outDir != null) {
      final outputPath = p.join(outDir, fileName);

      if (sourceFilePath != null) {
        // Memory-efficient: Copy file instead of loading into memory
        await File(sourceFilePath).copy(outputPath);
        _addLog('Saved downloaded file to: $outputPath (streamed)');
      } else if (bytes != null) {
        // In-memory: Write bytes
        await File(outputPath).writeAsBytes(bytes);
        _addLog('Saved downloaded file to: $outputPath');

        // Also create temp file for consistency
        final tempDir = await getTemporaryDirectory();
        final tempPath = p.join(tempDir.path, fileName);
        await File(tempPath).writeAsBytes(bytes);
        _tempFiles.add(tempPath);
      } else {
        throw ArgumentError('Either bytes or sourceFilePath must be provided');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(effectiveL10n.fileSaved(fileName))),
        );
      }
    } else {
      // Prompt user to save if no output dir
      if (bytes != null) {
        final result = await FilePicker.platform.saveFile(
          fileName: fileName,
          bytes: bytes,
        );
        if (result != null) {
          _addLog('Saved downloaded file to: $result');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(effectiveL10n.fileSaved(fileName))),
            );
          }
        }
      } else if (sourceFilePath != null) {
        // For streaming: read bytes for FilePicker (unavoidable for picker)
        final fileBytes = await File(sourceFilePath).readAsBytes();
        final result = await FilePicker.platform.saveFile(
          fileName: fileName,
          bytes: fileBytes,
        );
        if (result != null) {
          _addLog('Saved downloaded file to: $result');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(effectiveL10n.fileSaved(fileName))),
            );
          }
        }
      }
    }
  }

  void _showPushQrScanner({Uint8List? bytes, String? fileName}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDesktopNoScanner =
        !kIsWeb && (Platform.isLinux || Platform.isWindows);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pushViaQr),
        content: SizedBox(
          width: 300,
          height: 300,
          child: isDesktopNoScanner
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner,
                          size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        l10n.qrScanningUnsupported(
                            Platform.isLinux ? 'Linux' : 'Windows'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                )
              : MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String? code = barcodes.first.rawValue;
                      if (code != null &&
                          code.startsWith('securemark://receive')) {
                        Navigator.pop(context);
                        _handleReversePush(code,
                            pushBytes: bytes, pushFileName: fileName);
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

  void _showIdentityQrScanner(StateSetter setParentDialogState) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scannerTitle),
        content: SizedBox(
          width: 300,
          height: 300,
          child: !kIsWeb && (Platform.isLinux || Platform.isWindows)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        l10n.qrScanningUnsupported(
                            Platform.isLinux ? 'Linux' : 'Windows'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                )
              : MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String? code = barcodes.first.rawValue;
                      if (code != null) {
                        final messenger = ScaffoldMessenger.of(context);
                        // Accepts the identity-card URI, the legacy JSON
                        // format and bare keys (see parseIdentityCard).
                        final card = ForensicUtils.parseIdentityCard(code);
                        if (card != null &&
                            _isValidEd25519PublicKey(card.publicKey)) {
                          Navigator.pop(context);
                          setParentDialogState(() {
                            _identityBookmarks.add(IdentityBookmark(
                                name: card.name, publicKey: card.publicKey));
                          });
                          _saveBookmarks();
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text(l10n.identityAdded(card.name))),
                          );
                        } else {
                          messenger.showSnackBar(
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
}
