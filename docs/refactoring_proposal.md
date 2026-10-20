# SecureMark — Large-File Split Proposal

> Status: **proposal** — no code has been changed. This document records a plan
> only.

## 1. Context

The SecureMark codebase is already well organized into `lib/steganography/`,
`lib/utils/`, `lib/models/`, `lib/widgets/`, etc. — but two files never received
the same treatment and have grown far beyond what is comfortable to review or
maintain:

| File | Lines | Notes |
|------|-------|-------|
| `lib/pages/watermark_page.dart` | **12,747** | one `State` class (~12,000 lines, ~250 members) + 7 reusable widget classes appended at the bottom |
| `lib/watermark_processor.dart` | **2,458** | core processing engine, all `static` methods on one class |

Everything else in `lib/` is under ~700 lines.

## 2. Key architectural constraint

Both giant classes contain heavily-interconnected **private** (`_`) members:

- `WatermarkPageState` has ~200 private fields and methods.
- `WatermarkProcessor` has ~20 private `static` methods that reference each
  other, plus a public `WatermarkProcessor.processFile(...)` /
  `analyzeFileAsync(...)` API used by the page **and** by the unit tests.

In Dart, `_private` members are **library-private**, so they cannot be moved
into ordinary `import`ed files without renaming everything to public — a large,
error-prone diff.

The idiomatic solution is **`part` / `part of` files**: they belong to the same
library, so `_private` members stay private and cross-file access is preserved
**with zero public API change**.

The split is therefore:

- **`part` files** for the two giant classes (same library, keeps private access
  and the public API untouched).
- **Real widget files** in `lib/widgets/` for the genuinely self-contained
  classes already found at the bottom of the page file.

## 3. Proposal A — `lib/pages/watermark_page.dart`

### 3.1 Reusable widgets → `lib/widgets/` (pure wins, zero risk)

The classes at the bottom of the file (lines 12339–12747) have no coupling to
`WatermarkPageState`. They can be extracted verbatim and made public:

| Current class | New file |
|---------------|----------|
| `_DensityPainter` | `lib/widgets/density_painter.dart` |
| `_XYPadPainter` | `lib/widgets/xy_pad_painter.dart` |
| `_ColorTile` | `lib/widgets/color_tile.dart` |
| `_ProfileTile` | `lib/widgets/profile_tile.dart` |
| `_ComparisonClipper` | `lib/widgets/comparison_clipper.dart` |
| `_GradientButton` + `_PushDownWrapper` | `lib/widgets/gradient_button.dart` |

They become public classes (`DensityPainter`, `GradientButton`, …). Renames are
mechanical and contained (they are not referenced outside the current file).

### 3.2 The State class → `part` files

`watermark_page.dart` keeps: imports, the two top-level helpers
(`_isConfigBackupKey`, `_isIntPreferenceKey`), the `WatermarkPage` widget, **all
fields/controllers**, the lifecycle methods
(`initState`/`dispose`/`didChangeAppLifecycleState`), and `build()`.

Then, grouped by concern (line references are from the current file):

| Part file | Contents |
|-----------|----------|
| `parts/state.preferences.dart` | `_loadPreferences` (392), `_savePreference` (553), `_applyProfile` (581), `_loadProfileSettings` (683), `_saveAllCurrentSettings` (1071), `_saveCurrentConfigToProfile` (1105), `_resetProfileToDefaults` (1188), `_loadBookmarks` (369), `_saveBookmarks` (385), `_showResetProfilesModal` (11818) |
| `parts/state.config_backup.dart` | `_exportConfiguration` (11903), `_importConfiguration` (12031) |
| `parts/state.file_picking.dart` | `_pickFile` (10449), `_selectPaths` (10557), `_takePhoto` (10346), `_scanDocument` (10376), `_handleSharedContent` (1324), `_pickOutputDirectory` (317), `_pickLogoDirectory` (338) |
| `parts/state.processing.dart` | `_processPaths` (10677), `_applyWatermark` (11366), `_saveCurrent` (11392), `_shareCurrent` (11657), `_reset` (11203), `_cancelProcessing` (11161), `_createZipFromProcessedFiles` (11618), `_createProcessedZipBytes` (2944), `_downloadProcessedFiles` (2956), `_showSaveResultDialog` (11521), `_showProcessingErrorsDialog` (11569), `_startStopwatch` (11177), `_stopStopwatch` (11198), `_mimeTypeForPath` (11732), `_getSaveLocationInfo` (11486), `_getDisplayPath` (11512) |
| `parts/state.watermark_editing.dart` | `_selectWatermarkImage` (11282), `_loadLogoFromPath` (11337), `_updateColorMode` (11742), `_selectColor` (11760), `_buildFontDropdownItems` (11776), `_getFontSourceDescription` (11808), `_isQrContentValid` (11352) |
| `parts/state.forensics.dart` | `_showFileAnalyzer` (2068), `_pickAndAnalyze` (2625), `_performFileAnalysis` (5221), `_performBatchAnalysis` (5408), `_promptForZipPassword` (5631), `_saveExtractedFile` (6195), `_saveExtractedFileFromBatch` (6142), `_buildBatchAnalysisView` (5677), `_buildFileListItem` (5787), `_buildSummaryRow` (5850), `_getFileIcon` (5873), `_getSenderName` (5890), `_buildFileDetailView` (5902), `_showReceivedFileDetails` (5214), `_autoVerifyReceivedFile` (5162) |
| `parts/state.local_share.dart` | the send/receive system: `_showLocalShareDialog` (2847), `_buildSendTab` (2986), `_buildReceiveTab` (3499), `_handleReversePush` (3856), `_startServingEncrypted` (3976), `_sendDownloadAcknowledgment` (4373), `_downloadFromLocalUrl` (4409), `_saveDownloadedFile` (4951), `_showPushQrScanner` (5019), `_showIdentityQrScanner` (5090) — *~2,200 lines; may warrant a further split into `local_share.send` / `local_share.receive`* |
| `parts/state.steganography.dialogs.dart` | `_showSteganographyOptions` (6244), `_showQrWatermarkOptions` (6521), `_showSelectedFilesModal` (6801), `_showFontOptions` (7036), `_showExpertOptions` (7223), `_getFeatureIcon` (7970), `_getFeatureColor` (8001), `_getFeatureLabel` (8030) |
| `parts/state.web.dart` | `_buildWebRetentionBanner` (8063), `_webStartRetentionWindow` (10627), `_webEraseData` (10645), `_webRetentionRemainingLabel` (10667), `_showWebLegalDialog` (8875), `_showWebMentionsLegales` (8917), `_showWebConfidentialite` (8955), `_buildWebPrivacyBadge` (9021) |
| `parts/state.misc_dialogs.dart` | `_saveLogs` (1765), `_showLogs` (1839), `_showAboutDialog` (1892), `_checkForUpdates` (2005), `_showGuide` (9096), `_showIdentityDialog` (12150), `_showQrIdentityDialog` (12299), `_showIdentityBookmarksDialog` (2679) |
| `parts/state.builders.dart` | pure UI builders: `_buildProfileSelector` (1627), `_getProfileLabel` (1652), `_getProfileIcon` (1673), `_buildControlsPanel` (1694), `_buildPreviewPanel` (8083), `_getLocalizedVerificationMessage` (8704), `_buildForensicRow` (8718), `_buildPreviewToggleItem` (8752), `_buildAuthorFooter` (8791), `_buildPrimaryActionCard` (9108), `_buildApplyFloatingButton` (9346), `_buildActionButtons` (9369), `_buildCombinedWatermarkCard` (9514), `_buildUnifiedVisualDashboard` (9726), `_buildWatermarkTypeCard` (9857), `_buildLogoButton` (9941), `_buildAllOptions` (9965), `_buildStatusIcons` (10295) |

The main file shrinks from 12,747 lines to roughly **600–800 lines**.

## 4. Proposal B — `lib/watermark_processor.dart`

Same `part` approach (preserves the `WatermarkProcessor.*` static API and the
isolate entry points):

| Part file | Contents |
|-----------|----------|
| `watermark_processor.dart` | `WatermarkCacheInput` typedef, `WatermarkProcessor` class, public API (`processFile` (110), `clearCache` (97), `isSupportedFile` (107), `analyzeFileAsync` (2107), …), cache logic (`_generateCacheKey`, `_addToCache`) |
| `parts/processor.image_pipeline.dart` | `_processImage` (358), `_runImagePipeline` (634), `_imageIsolateEntry` (703), `_renderWatermarkedImageBytes` (708), `_renderTextWithFlutterCanvas` (2402), `_bytesFromParam` (621), `_watermarkCount` (1878), `_randomAngle` (1882), `_randomWatermarkColor` (1885) |
| `parts/processor.pdf_pipeline.dart` | `_processPdf` (989), `_runPdfPipeline` (1267), `_pdfIsolateEntry` (1316), `_processPdfRasterFallback` (1323), `_renderWatermarkedPdfBytes` (1608), `_applySecurityToSyncDocument` (2433), `_resolveSyncfusionColor` (1891) |
| `parts/processor.image_inspection.dart` | `_getImageDimensions` (1908), `_getJpegDimensions` (1921), `_getPngDimensions` (1981), `_checkResolutionBeforeDecode` (2017), `_sanitizeJpegMarkers` (2050), `_detectCameraModel` (2075) |
| `parts/processor.forensics.dart` | `analyzeFileAsync` (2107), `analyzeImageAsync` (2122), `extractFileAsync` (2128), `_analyzePdfVector` (2134), `analyzeImage` (2232), `_parseSignatureFromPayload` (2361) |

> Note: all line references above reflect the files at the time this proposal was
> written. They are directional — the authoritative grouping is the method name,
> not the line number.

## 5. Gotchas to respect during the split

1. **Isolate entry points must stay `static`** (`_imageIsolateEntry`,
   `_pdfIsolateEntry`) — `Isolate.spawn` requires top-level or static functions.
   As `part of` the same library they remain static and callable; do not convert
   them to instance methods.
2. **`_renderTextWithFlutterCanvas` must stay on the main isolate** (uses
   `dart:ui` TextPainter). It already runs on the main thread before the isolate
   is spawned — keep that ordering.
3. **`TransferableTypedData` zero-copy transfers** and the **DCT lookup-table
   pre-computation** live inside the image/PDF parts — move them whole; never
   split a single method across parts.
4. **Part files must not re-import** what the parent already imports; imports go
   only in the parent file (`watermark_page.dart` / `watermark_processor.dart`),
   and parts inherit them.
5. **Localization**: dialogs use `AppLocalizations.of(context)!` locally — no
   `.arb` changes and no `flutter gen-l10n` are required, since no user-facing
   strings change.

## 6. Test and verification impact

- **Zero public API change** → all existing tests should compile unchanged:
  `test/unit/watermark_processor_test.dart`,
  `test/unit/watermark_processor_extended_test.dart`,
  `test/unit/steganography_test.dart`, `test/unit/streaming_test.dart`,
  `test/unit/web_pipeline_test.dart`, `test/unit/error_handling_test.dart`,
  `test/widget_test.dart`, and the rest.

- The only renames are the 7 bottom widget classes going `_Private` → public;
  `grep` shows they are not referenced outside the current file, so there are
  expected to be **zero call-site changes**.

## 7. Phased migration (each step leaves a green build)

1. **Phase 1 — widgets**: extract the 7 bottom widget classes into
   `lib/widgets/`. Run `./build_and_verify.sh quality_checks`.
   *(purest, lowest risk)*
2. **Phase 2 — processor**: split `watermark_processor.dart` into parts.
   Verify with `flutter analyze` + full `flutter test`.
3. **Phase 3 — page**: split `watermark_page.dart` into parts, one at a time,
   starting with the most self-contained (`state.builders`,
   `state.preferences`, `state.web`) and finishing with the large
   `state.local_share`. Verify after each part.
4. **Phase 4 — final pass**: `dart format .` then
   `./build_and_verify.sh quality_checks` (must be 0 errors, 32 tests passing).

Net result: no file exceeds ~2,200 lines (and `state.local_share` can be halved
further in a follow-up), with **no behavioral change**.

## 8. Acceptance criteria

- [ ] `flutter analyze` reports zero errors/warnings.
- [ ] `dart format --output=none --set-exit-if-changed .` passes.
- [ ] All 32 unit/widget tests pass (`flutter test`).
- [ ] `./build_and_verify.sh quality_checks` exits 0.
- [ ] No file in `lib/` exceeds 2,500 lines.
- [ ] No public API (`WatermarkProcessor.*`, `WatermarkPage`, models, error
      types) changed.