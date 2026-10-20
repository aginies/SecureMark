part of '../watermark_page.dart';

/// Pure UI builders (panels, cards, dashboards, status icons) for the watermark page.

extension _WatermarkPageStateBuildersPart on WatermarkPageState {
  /// Standard padding/shape for the secondary action buttons (save, share,
  /// reset) — used across panels to avoid duplicated [ButtonStyle] literals.
  static final ButtonStyle _secondaryActionStyle = ButtonStyle(
    padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
    shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  Widget _buildProfileSelector(ThemeData theme, AppLocalizations l10n) {
    final availableProfiles = SettingsProfile.values.toList();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.0,
      children: availableProfiles.map((profile) {
        return ProfileTile(
          profile: profile,
          label: _getProfileLabel(profile, l10n),
          icon: _getProfileIcon(profile),
          isSelected: _selectedProfile == profile,
          theme: theme,
          onTap: () => _applyProfile(profile),
          onLongPress: () => _saveCurrentConfigToProfile(profile),
          processing: _processing,
        );
      }).toList(),
    );
  }

  String _getProfileLabel(SettingsProfile profile, AppLocalizations l10n) {
    switch (profile) {
      case SettingsProfile.none:
        return l10n.profileNone;
      case SettingsProfile.secureIdentity:
        return l10n.profileSecureIdentity;
      case SettingsProfile.onlineImage:
        return l10n.profileOnlineImage;
      case SettingsProfile.qrCode:
        return l10n.profileQrCode;
      case SettingsProfile.integrity:
        return l10n.profileIntegrity;
      case SettingsProfile.shareDocument:
        return l10n.profileShareDocument;
      case SettingsProfile.p1:
        return l10n.profileP1;
      case SettingsProfile.p2:
        return l10n.profileP2;
    }
  }

  IconData _getProfileIcon(SettingsProfile profile) {
    switch (profile) {
      case SettingsProfile.none:
        return Icons.not_interested;
      case SettingsProfile.secureIdentity:
        return Icons.fingerprint;
      case SettingsProfile.onlineImage:
        return Icons.public;
      case SettingsProfile.qrCode:
        return Icons.qr_code;
      case SettingsProfile.integrity:
        return Icons.verified_outlined;
      case SettingsProfile.shareDocument:
        return Icons.description;
      case SettingsProfile.p1:
        return Icons.tune;
      case SettingsProfile.p2:
        return Icons.tune;
    }
  }

  Widget _buildControlsPanel(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upload comes first: choosing a file is step 1, the preset profiles
        // only re-shape the options of whatever is loaded.
        _buildPrimaryActionCard(),
        const SizedBox(height: 16),
        _buildProfileSelector(theme, l10n),
        const SizedBox(height: 16),
        _buildCombinedWatermarkCard(),
        const SizedBox(height: 16),
        if (_buildStatusIcons(l10n) != null) ...[
          _buildStatusIcons(l10n)!,
          const SizedBox(height: 16),
        ],
        _buildActionButtons(),
        if (!_processing && _statusMessage.isNotEmpty && !_hasErrors) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _statusMessage,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
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
                      if (kIsWeb && _webRetentionDeadline != null)
                        _buildWebRetentionBanner(theme, l10n),
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
                    if (kIsWeb && _webRetentionDeadline != null)
                      _buildWebRetentionBanner(theme, l10n),
                    Text(
                      File(_currentProcessedFile!.sourcePath)
                          .uri
                          .pathSegments
                          .last,
                      style: theme.textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Applied features display
                    if (_processedFiles[_previewIndex]
                        .result
                        .appliedFeatures
                        .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: _processedFiles[_previewIndex]
                              .result
                              .appliedFeatures
                              .map((key) {
                            final icon = _getFeatureIcon(key);
                            final color = _getFeatureColor(key);
                            final label = _getFeatureLabel(key, l10n);

                            return Tooltip(
                              message: label,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.3)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ColorUtils.getAdaptiveShadowColor(
                                          theme,
                                          color: color,
                                          alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Icon(
                                  icon,
                                  size: 28,
                                  color: color,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: PageView.builder(
                          controller: _previewController,
                          itemCount: _processedFiles.length,
                          onPageChanged: (index) {
                            _refresh(() {
                              _previewIndex = index;
                            });
                            _transformationController.value =
                                Matrix4.identity();
                          },
                          itemBuilder: (context, index) {
                            final previewBytes =
                                _processedFiles[index].result.previewBytes;
                            if (previewBytes == null) {
                              // Only the native engines rasterize a PDF, so a
                              // processed PDF has no preview on the web. Tell the
                              // user where to find the result instead of showing
                              // an empty box.
                              final resultIsPdf =
                                  _processedFiles[index].result.isPdf;
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        resultIsPdf
                                            ? Icons.picture_as_pdf_outlined
                                            : Icons
                                                .image_not_supported_outlined,
                                        size: 56,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        resultIsPdf
                                            ? l10n.pdfNoPreviewHint
                                            : l10n.previewUnavailable,
                                        style: theme.textTheme.bodyMedium,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
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
                                              aspectRatio:
                                                  (_processedFiles[index]
                                                                  .result
                                                                  .width !=
                                                              null &&
                                                          _processedFiles[index]
                                                                  .result
                                                                  .height !=
                                                              null &&
                                                          _processedFiles[index]
                                                                  .result
                                                                  .width! >
                                                              0 &&
                                                          _processedFiles[index]
                                                                  .result
                                                                  .height! >
                                                              0)
                                                      ? _processedFiles[index]
                                                              .result
                                                              .width! /
                                                          _processedFiles[index]
                                                              .result
                                                              .height!
                                                      : 1.0,
                                              child: Builder(
                                                  builder: (sliderContext) {
                                                return LayoutBuilder(builder:
                                                    (context, constraints) {
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
                                                        clipper: ComparisonClipper(
                                                            _comparisonSliderValue,
                                                            isVertical: false),
                                                        child: Image.memory(
                                                          _processedFiles[index]
                                                              .result
                                                              .originalBytes!,
                                                          fit: BoxFit.fill,
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
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
                                                          onPanUpdate:
                                                              (details) {
                                                            final RenderBox?
                                                                box =
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
                                                              _refresh(() {
                                                                _comparisonSliderValue =
                                                                    (localOffset.dy /
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
                                                                color: Colors
                                                                    .white,
                                                                shape: BoxShape
                                                                    .circle,
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: ColorUtils.getAdaptiveShadowColor(
                                                                        theme,
                                                                        alpha:
                                                                            0.3),
                                                                    blurRadius:
                                                                        8,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            2),
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
                                                              PreviewMode
                                                                  .heatmap &&
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
                                            color: ColorUtils
                                                .getAdaptiveShadowColor(theme,
                                                    alpha: 0.1),
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
                                            onTap: () => _refresh(() =>
                                                _previewMode =
                                                    PreviewMode.original),
                                            theme: theme,
                                            tooltip: l10n.previewModeOriginal,
                                          ),
                                          _buildPreviewToggleItem(
                                            icon: Icons.auto_fix_high,
                                            isSelected: _previewMode ==
                                                PreviewMode.processed,
                                            onTap: () => _refresh(() =>
                                                _previewMode =
                                                    PreviewMode.processed),
                                            theme: theme,
                                            tooltip: l10n.previewModeProcessed,
                                          ),
                                          if (!isMobile &&
                                              !(_processedFiles[index]
                                                      .result
                                                      .isPdf &&
                                                  Platform.isMacOS))
                                            _buildPreviewToggleItem(
                                              icon: Icons.compare,
                                              isSelected: _previewMode ==
                                                  PreviewMode.slider,
                                              onTap: () => _refresh(() =>
                                                  _previewMode =
                                                      PreviewMode.slider),
                                              theme: theme,
                                              tooltip:
                                                  l10n.sliderComparisonTooltip,
                                            ),
                                          if (_processedFiles[index]
                                                  .result
                                                  .heatmapBytes !=
                                              null)
                                            _buildPreviewToggleItem(
                                              icon: Icons.contrast,
                                              isSelected: _previewMode ==
                                                  PreviewMode.heatmap,
                                              onTap: () => _refresh(() =>
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
                                            color: ColorUtils
                                                .getAdaptiveShadowColor(theme,
                                                    alpha: 0.2),
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
                                // Arrows are needed on desktop (no swipe)
                                // and on web (mouse users); mobile pages by
                                // swipe. kIsWeb must short-circuit first:
                                // Platform.* throws when evaluated on web.
                                if (_processedFiles.length > 1 &&
                                    (kIsWeb ||
                                        Platform.isLinux ||
                                        Platform.isWindows ||
                                        Platform.isMacOS)) ...[
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
                                      // Top-right: the bottom-right corner of
                                      // the preview belongs to the Apply FAB.
                                      top: 8,
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
    final l10n = AppLocalizations.of(context)!;
    // One compact line: author · version · (guide) · legal links.
    // Plain Inkwells instead of buttons: no minimum touch height, so the
    // footer stays a single slim row even under the narrow controls column.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      // Wrap (not Row): if the line ever overflows the narrow controls
      // column, wrapping is the graceful failure mode.
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: 0,
        children: [
          InkWell(
            onTap: _showAboutDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Antoine Giniès',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_appVersion.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      'v$_appVersion',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Tooltip(
            message: l10n.showGuide,
            child: InkWell(
              onTap: _showGuide,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child:
                    Icon(Icons.help_outline, size: 14, color: theme.hintColor),
              ),
            ),
          ),
          // Web-only legal links (French legal requirement). The texts are
          // French-only on purpose: the French version is the official one.
          if (kIsWeb) ...[
            InkWell(
              onTap: _showWebConfidentialite,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child:
                    Text('Confidentialité', style: theme.textTheme.labelSmall),
              ),
            ),
            InkWell(
              onTap: _showWebMentionsLegales,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child:
                    Text('Mentions légales', style: theme.textTheme.labelSmall),
              ),
            ),
          ],
        ],
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
            child: GradientButton(
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
                  child: GradientButton(
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
                  child: GradientButton(
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
              child: GradientButton(
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

      return GradientButton(
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
      // 4px = Card's default margin: this keeps the import CTA flush with the
      // profile grid and the cards below it instead of sitting 12px narrower.
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_supportsDesktopDrop)
            DropTarget(
              onDragEntered: (_) => _refresh(() => _dragging = true),
              onDragExited: (_) => _refresh(() => _dragging = false),
              onDragDone: (detail) async {
                _refresh(() => _dragging = false);
                if (detail.files.isEmpty) return;
                final paths = detail.files
                    .map((file) => file.path)
                    .whereType<String>()
                    .toSet()
                    .toList();
                if (paths.isNotEmpty) {
                  _refresh(() => _loadingFiles = true);
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

  /// Floating Apply button over the preview panel (Scaffold.floatingActionButton
  /// at the default endFloat location). Guarded by [_canApplyWatermark], so it
  /// greys out under the same conditions as the app-bar magic wand.
  Widget _buildApplyFloatingButton(AppLocalizations l10n, ThemeData theme) {
    final enabled = _canApplyWatermark;
    final colorScheme = theme.colorScheme;
    // Match the default Material 3 FAB when enabled; grey the whole button out
    // when it can't run yet (no files selected, image watermark without an
    // image, or a run in progress) so the "nothing to apply" state is obvious.
    final background =
        enabled ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final foreground = enabled
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.38);
    const radius = BorderRadius.all(Radius.circular(16));

    // Lift the button above the author footer ("Antoine Giniès vX.X.X"), which
    // otherwise sits under it at the bottom of the mobile scroll view.
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Material(
        elevation: 6,
        color: background,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: enabled ? _applyWatermark : null,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_fix_high, color: foreground),
                const SizedBox(width: 12),
                Text(
                  l10n.apply,
                  style:
                      theme.textTheme.titleMedium?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      shadowColor: ColorUtils.getAdaptiveShadowColor(theme, alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The apply CTA itself moved to the floating button; this card
            // keeps the error strip and the output / save / share actions.
            if (_hasErrors && _statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: InkWell(
                  onTap: _showLogs,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              theme.colorScheme.error.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.error, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: theme.colorScheme.error, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Output Directory Selection (if not web)
            if (!kIsWeb) ...[
              OutlinedButton.icon(
                onPressed: _processing ? null : _pickOutputDirectory,
                icon: const Icon(Icons.folder_open, size: 20),
                label: Text(
                  _outputDirectory != null
                      ? l10n.outputDirectoryLabel(p.basename(_outputDirectory!))
                      : l10n.selectOutputDirectory,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Secondary buttons row/wrap
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                PushDownWrapper(
                  enabled: !_processing && _processedFiles.isNotEmpty,
                  child: FilledButton.tonalIcon(
                    onPressed: _processing || _processedFiles.isEmpty
                        ? null
                        : _saveCurrent,
                    icon: const Icon(Icons.save_alt),
                    label: Text(l10n.saveAll),
                    style: _secondaryActionStyle,
                  ),
                ),
                PushDownWrapper(
                  enabled: !_processing && _processedFiles.isNotEmpty,
                  child: FilledButton.tonalIcon(
                    onPressed: _processing || _processedFiles.isEmpty
                        ? null
                        : _shareCurrent,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.shareAll),
                    style: _secondaryActionStyle,
                  ),
                ),
                PushDownWrapper(
                  enabled: !_processing,
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : _reset,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.reset),
                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return theme.colorScheme.surfaceContainerHighest;
                        }
                        return theme.colorScheme.surface;
                      }),
                      padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
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
                onDragEntered: (_) => _refresh(() => _logoDragging = true),
                onDragExited: (_) => _refresh(() => _logoDragging = false),
                onDragDone: (detail) async {
                  _refresh(() => _logoDragging = false);
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
                    ColorTile(
                      processing: _processing,
                      isCircle: false,
                      onTap: () => _updateColorMode(true),
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
                      return ColorTile(
                        processing: _processing,
                        onTap: () {
                          _updateColorMode(false);
                          _selectColor(color);
                        },
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: 1.0,
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
                        _refresh(() {
                          _logoSize = value;
                        });
                      },
              ),
              const SizedBox(height: 12),
              if (!kIsWeb)
                OutlinedButton.icon(
                  onPressed: _processing ? null : _pickLogoDirectory,
                  icon: const Icon(Icons.folder_shared_outlined, size: 18),
                  label: Text(
                    _logoDirectory != null
                        ? l10n.logoDirectoryLabel(p.basename(_logoDirectory!))
                        : l10n.selectLogoDirectory,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
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

        _refresh(() {
          _transparency = (1.0 - newX) * 100;
          _density = 10 + ((1.0 - newY) * 80);
        });
      },
      // Persist once per gesture (not per move event) — a pan fires dozens of
      // pointer updates per second and each _savePreference is a disk write.
      onPanEnd: (_) {
        _savePreference('transparency', _transparency);
        _savePreference('density', _density);
      },
      onTapDown: (details) {
        if (_processing) return;
        final newX = (details.localPosition.dx / width).clamp(0.0, 1.0);
        final newY = (details.localPosition.dy / height).clamp(0.0, 1.0);

        _refresh(() {
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
                  painter: DensityPainter(
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
                painter: XYPadPainter(
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
                      color:
                          ColorUtils.getAdaptiveShadowColor(theme, alpha: 0.3),
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
                  color: ColorUtils.getAdaptiveShadowColor(theme,
                      color: colorScheme.primary, alpha: 0.25),
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
                  _refresh(() {
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
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
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
            _refresh(() {
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
        icon: _steganographyVerificationFailed
            ? Icons.gpp_bad
            : Icons.verified_user_outlined,
        enabledColor:
            _steganographyVerificationFailed ? Colors.red : Colors.green,
        isEnabled: _useSteganography,
        isAvailable: !_rasterizePdf,
        unavailableReason: _rasterizePdf ? l10n.unavailableRasterPdf : null,
        subtitle: _steganographyVerificationFailed
            ? l10n.steganographyVerificationFailed
            : (_useSteganography ? l10n.steganographyEnabledHint : null),
        onToggle: () {
          if (!_rasterizePdf) {
            _refresh(() {
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
              } else {
                // Enforce minimum 85% JPEG quality for steganography
                if (_jpegQuality < 85) {
                  _jpegQuality = 85;
                  _savePreference('jpegQuality', 85);
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
            _refresh(() {
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
          _refresh(() {
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
          _refresh(() {
            _qrVisible = !_qrVisible;
          });
          _savePreference('qrVisible', _qrVisible);
        },
        onConfigure: _showQrWatermarkOptions,
      ),

      // Hide File (Steganography) (not part of the web UI)
      if (!kIsWeb)
        WatermarkOption(
          id: 'hide_file',
          label: l10n.hideFileOption,
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
                _refresh(() {
                  _hideFileWithSteganography = !_hideFileWithSteganography;
                });
                _savePreference(
                    'hideFileWithSteganography', _hideFileWithSteganography);
              }
            }
          },
          onConfigure: _showSteganographyOptions,
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
          _refresh(() {
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
          _refresh(() {
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
          _refresh(() {
            _preserveMetadata = !_preserveMetadata;
          });
          _savePreference('preserveMetadata', _preserveMetadata);
        },
        onConfigure: _showExpertOptions,
      ),

      // Force PNG
      WatermarkOption(
        id: 'force_png',
        label: l10n.forcePngTitle,
        icon: Icons.image_search_outlined,
        enabledColor: Colors.blueGrey,
        isEnabled: _forcePng,
        subtitle: _forcePng ? l10n.forcePngEnabledHint : null,
        onToggle: () {
          _refresh(() {
            _forcePng = !_forcePng;
          });
          _savePreference('forcePng', _forcePng);
        },
        onConfigure: _showFontOptions,
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
          _refresh(() {
            _targetSize = _targetSize == null ? 1280 : null;
          });
          _savePreference('targetSize', _targetSize);
        },
        onConfigure: _showFontOptions,
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

      // Secure ZIP
      WatermarkOption(
        id: 'secure_zip',
        label: l10n.secureZipTitle,
        icon: Icons.folder_zip,
        enabledColor: Colors.deepOrange,
        isEnabled: _useSecureZip,
        isAvailable: _secureZipPasswordController.text.isNotEmpty,
        unavailableReason: l10n.secureZipPasswordRequired,
        subtitle: _useSecureZip ? l10n.enableSecureZip : null,
        onToggle: () {
          _refresh(() {
            _useSecureZip = !_useSecureZip;
            if (_useSecureZip) {
              _zipOutputs = true; // Auto-enable zip
            }
          });
          _savePreference('useSecureZip', _useSecureZip);
          if (_useSecureZip) {
            _savePreference('zipOutputs', true);
          }
        },
        onConfigure: _showExpertOptions,
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
            _refresh(() {
              _zipOutputs = !_zipOutputs;
            });
            _savePreference('zipOutputs', _zipOutputs);
          }
        },
        onConfigure: null, // No settings dialog
      ),
      // Steganography stays hidden in the web UI (behavior unchanged): the
      // old expert-mode gate was never reachable there.
    ].where((option) {
      if (kIsWeb &&
          (option.id == 'steganography' || option.id == 'robust_stego')) {
        return false;
      }
      return true;
    }).toList();
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
}
