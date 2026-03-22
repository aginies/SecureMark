// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SecureMark';

  @override
  String get emptyPreviewHint =>
      'Enter watermark text and pick one or more image or PDF files';

  @override
  String get selectedPreviewHint =>
      'Files selected. Click Apply SecureMark to generate previews';

  @override
  String selectedFilesLabel(int count) {
    return 'Selected Files ($count)';
  }

  @override
  String get clickApplyToPreview =>
      'Click \"Apply SecureMark\" to generate previews';

  @override
  String get previewUnavailable => 'Preview unavailable';

  @override
  String swipeHint(int current, int total) {
    return 'Swipe left for next, right for previous ($current/$total)';
  }

  @override
  String get processingFile => 'Processing file...';

  @override
  String get applyingWatermark => 'Applying watermark...';

  @override
  String get processingValidating => 'Validating file...';

  @override
  String get processingProcessing => 'Processing file...';

  @override
  String get processingCached => 'Retrieved from cache';

  @override
  String get processingComplete => 'Processing complete';

  @override
  String get processingFlattening => 'Rasterizing PDF (flattening)...';

  @override
  String get authorFooter => 'Author: Antoine Giniès';

  @override
  String get pickFiles => 'Images or PDF';

  @override
  String selectedFile(String name) {
    return 'Selected file: $name';
  }

  @override
  String selectedFiles(int count) {
    return 'Selected files: $count';
  }

  @override
  String get applyWatermark => 'Apply SecureMark';

  @override
  String get saveAll => 'Save All';

  @override
  String get shareAll => 'Share All';

  @override
  String get reset => 'Reset';

  @override
  String get watermarkTextLabel => 'Text to Stamp (+Date-time)';

  @override
  String get watermarkTextHint => 'Enter the text to stamp';

  @override
  String get randomColor => 'Random color';

  @override
  String get selectedColor => 'Selected color';

  @override
  String transparencyValue(int value) {
    return 'Watermark Transparency: $value%';
  }

  @override
  String densityValue(int value) {
    return 'Density: $value%';
  }

  @override
  String get droppedPathUnavailable =>
      'The dropped file paths are unavailable.';

  @override
  String get desktopDropArea => 'Drop Files Here';

  @override
  String get pickerLabel => 'Images and PDFs';

  @override
  String processingCount(int count) {
    return 'Processing 1/$count files...';
  }

  @override
  String processingNamedFile(int current, int total, String name) {
    return 'Processing $current/$total: $name';
  }

  @override
  String get processingFailed => 'Unsupported file or processing failed.';

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String savedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Saved $_temp0.';
  }

  @override
  String get shareSubject => 'Watermarked files';

  @override
  String get shareText => 'Shared from SecureMark';

  @override
  String sharedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Shared $_temp0.';
  }

  @override
  String shareOpenedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Share sheet opened for $_temp0.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get saveLocationInfo =>
      'Files will be saved in the same folder as originals with \'securemark-\' prefix';

  @override
  String get expertOptions => 'Expert Options';

  @override
  String fontSizeValue(int value) {
    return 'Font Size: ${value}px';
  }

  @override
  String jpegQualityValue(int value) {
    return 'JPEG Quality: $value%';
  }

  @override
  String imageResizingLabel(String size) {
    return 'Image Resizing: $size';
  }

  @override
  String get resizeNone => 'None (Original)';

  @override
  String pixelUnit(int value) {
    return '$value px';
  }

  @override
  String get includeTimestampFilename => 'Include Date & Hour in Filename';

  @override
  String get preserveExifData => 'Preserve File Metadata (EXIF/PDF Info)';

  @override
  String get rasterizePdfTitle => 'Rasterize PDF (Flatten)';

  @override
  String get rasterizePdfSubtitle =>
      'Convert PDF pages to images for maximum security (bigger size and slower)';

  @override
  String get steganographyTitle => 'Steganography (Invisible Signature)';

  @override
  String get steganographySubtitle => 'Embed text secretly in pixels.';

  @override
  String get robustSteganographyTitle => 'Robust Watermarking (DCT Domain)';

  @override
  String get robustSteganographySubtitle =>
      'Experimental: Survives re-compression and resizing better than LSB.';

  @override
  String get filePrefixLabel => 'File Prefix';

  @override
  String get filePrefixHint => 'e.g., watermark-';

  @override
  String get resetExpertHint =>
      'This will reset all expert settings and file prefix to defaults.';

  @override
  String get fontStyleLabel => 'Font Style';

  @override
  String get fontSelectionNote =>
      'Note: Using optimized bitmap fonts for fast cross-platform rendering.';

  @override
  String get fontSelectionNoteGoogle =>
      'Note: Using Google Fonts for enhanced typography. Requires internet for first use.';

  @override
  String get fontSelectionNoteAsset =>
      'Note: Using custom TTF font for enhanced typography. Requires font files in assets/fonts/.';

  @override
  String get resetToDefaults => 'Reset to Defaults';

  @override
  String outputDirectoryLabel(String path) {
    return 'Output Directory: $path';
  }

  @override
  String get selectOutputDirectory => 'Select Output Directory';

  @override
  String get viewLogs => 'View Logs';

  @override
  String get appLogs => 'App Logs';

  @override
  String get noLogsYet => 'No logs yet';

  @override
  String get openGitHub => 'Open GitHub Repository';

  @override
  String get close => 'Close';

  @override
  String get aboutApp => 'About SecureMark';

  @override
  String get appDescription =>
      'A professional application to secure documents with watermarks for safe sharing.';

  @override
  String authorLabel(String name) {
    return 'Author: $name';
  }

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get checkingForUpdates => 'Checking for updates...';

  @override
  String get upToDate => 'You are using the latest version.';

  @override
  String updateAvailable(String version) {
    return 'A new version ($version) is available!';
  }

  @override
  String get updateCheckError => 'Could not check for updates.';

  @override
  String get githubRepository => 'GitHub Repository';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get viewUpdate => 'View';

  @override
  String get analyzeFile => 'Analyze File (LSB)';

  @override
  String get fileAnalyzerTitle => 'File Analyzer (LSB)';

  @override
  String get fileAnalyzerDescription =>
      'Select a file to check for hidden SecureMark signatures.';

  @override
  String get pickAndAnalyze => 'Pick and Analyze';

  @override
  String signatureFound(String message) {
    return '✅ Signature found: \"$message\"';
  }

  @override
  String robustSignatureFound(String message) {
    return '💪 Robust signature found: \"$message\"';
  }

  @override
  String get noSignatureFound =>
      '❌ No SecureMark signature detected in this file.';

  @override
  String analysisError(String error) {
    return 'Error during analysis: $error';
  }

  @override
  String get analysisResult => 'Result:';

  @override
  String get steganographyVerified => 'Steganography Verified';

  @override
  String get steganographyVerificationFailed =>
      'Steganography verification failed';

  @override
  String get steganographyEnabledHint =>
      'Steganography is enabled and will be applied';

  @override
  String get hideFileWithSteganographyTitle => 'Hide a file (experimental)';

  @override
  String get hideFileWithSteganographySubtitle =>
      'Embed an entire file within the image (might increase output size)';

  @override
  String get selectFileToHide => 'Select File to Hide';

  @override
  String selectedHiddenFile(String name) {
    return 'Hidden file: $name';
  }

  @override
  String get hiddenFileSecurityWarning =>
      'Security Notice: Hidden files are only secure if encrypted before embedding. Steganography obscures but does not encrypt your data.';

  @override
  String get steganographyPasswordLabel => 'Encryption Password';

  @override
  String get steganographyPasswordHint =>
      'Enter password to protect hidden file';

  @override
  String get steganographyPasswordNote =>
      'Note: This password will be required to extract the hidden file using SecureMark. It uses AES-256 encryption.';

  @override
  String get zipAllFiles => 'ZIP All Files';

  @override
  String get zipEnabledHint => 'ZIP compression enabled for sharing';

  @override
  String get zipDisabledHint => 'ZIP compression disabled';

  @override
  String get qrWatermarkTitle => 'QR Code Watermark';

  @override
  String get enableQrWatermark => 'Enable QR Code';

  @override
  String get enableQrWatermarkSubtitle => 'Embed metadata in a QR code';

  @override
  String get qrMode => 'QR Code Mode';

  @override
  String get qrVisibleMode => 'Visible QR Code';

  @override
  String get qrVisibleModeDesc => 'Show QR code on the image';

  @override
  String get qrInvisibleMode => 'Invisible QR Code (LSB)';

  @override
  String get qrInvisibleModeDesc =>
      'Hide QR data in pixels (requires PNG output)';

  @override
  String get qrAuthorLabel => 'Author Name';

  @override
  String get qrAuthorHint => 'e.g., John Doe';

  @override
  String get qrUrlLabel => 'URL or Website';

  @override
  String get qrUrlHint => 'e.g., https://example.com';

  @override
  String get qrVisibleOptions => 'Visible QR Options';

  @override
  String get qrPositionLabel => 'QR Code Position';

  @override
  String get qrPosTopLeft => 'Top Left';

  @override
  String get qrPosTopRight => 'Top Right';

  @override
  String get qrPosBottomLeft => 'Bottom Left';

  @override
  String get qrPosBottomRight => 'Bottom Right';

  @override
  String get qrPosCenter => 'Center';

  @override
  String qrSizeValue(int value) {
    return 'QR Code Size: ${value}px';
  }

  @override
  String qrOpacityValue(int value) {
    return 'QR Code Opacity: $value%';
  }

  @override
  String get qrInvisibleNote =>
      'Note: To hide the QR code invisibly (LSB), use the Steganography menu.';

  @override
  String receivedFilesFromSharing(int count) {
    return '📥 Received $count file(s) from sharing';
  }

  @override
  String get unsupportedSharedFormat =>
      '⚠️ Shared files are not in a supported format (JPG, PNG, WebP, PDF, HEIC/HEIF)';

  @override
  String get signatureCopied => 'Signature copied to clipboard';

  @override
  String get saveHiddenFile => 'Save Hidden File';

  @override
  String fileSaved(String name) {
    return 'File saved: $name';
  }

  @override
  String errorSavingFile(String error) {
    return 'Error saving file: $error';
  }

  @override
  String antiAiProtectionValue(int value) {
    return 'Anti-AI Protection: $value%';
  }

  @override
  String get qrContentType => 'QR Content Type';

  @override
  String get qrTypeMetadata => 'Metadata (JSON)';

  @override
  String get qrTypeUrl => 'Website Redirect';

  @override
  String get qrTypeVCard => 'Contact (vCard)';

  @override
  String get vCardFirstName => 'First Name';

  @override
  String get vCardLastName => 'Last Name';

  @override
  String get vCardPhone => 'Phone Number';

  @override
  String get vCardEmail => 'Email Address';

  @override
  String get vCardOrg => 'Organization';

  @override
  String get invalidUrlError =>
      'Please enter a valid URL (e.g., https://example.com)';

  @override
  String qrDataExtracted(String data) {
    return '✅ QR Code found: $data';
  }

  @override
  String get noQrFound => '❌ No QR code detected';

  @override
  String get abToggleTooltipOriginal => 'Show Original';

  @override
  String get abToggleTooltipProcessed => 'Show Processed';

  @override
  String get processingCancelled => 'Processing cancelled';

  @override
  String processingStatusMultiple(int successCount, int failedCount) {
    return 'Processed $successCount files successfully. $failedCount files failed.';
  }

  @override
  String get processingFailedSingle =>
      'Failed to process file. Please check the file format and try again.';

  @override
  String processingFailedMultiple(int count) {
    return 'Failed to process $count files. Please check the file formats and try again.';
  }

  @override
  String fileSavedTo(String path) {
    return 'File saved to: $path';
  }

  @override
  String get saveFailedGeneral =>
      'Failed to save files. Please check permissions and storage space.';

  @override
  String saveStatusMultiple(int successCount, int failedCount) {
    return 'Saved $successCount files. $failedCount files failed.';
  }

  @override
  String get filesSavedTitle => 'Files Saved';

  @override
  String successfullySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Successfully saved $_temp0:';
  }

  @override
  String failedSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Failed to save $_temp0:';
  }

  @override
  String willSaveAsIn(String name, String path) {
    return 'Will save as: $name in $path/';
  }

  @override
  String willSaveMultipleIn(int count, String path) {
    return 'Will save $count files to: $path/';
  }

  @override
  String get savingFiles => 'Saving files...';

  @override
  String errorSavingFiles(String error) {
    return 'Error saving files: $error';
  }

  @override
  String get foregroundTaskTitle => 'SecureMark Processing';

  @override
  String get foregroundTaskDescription =>
      'Showing progress of document watermarking';

  @override
  String foregroundTaskUpdate(int current, int total, String name) {
    return 'Processing file $current of $total: $name';
  }
}
