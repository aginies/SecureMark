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
  String get takePhoto => 'Take Photo';

  @override
  String get takePhotoSubtitle => 'Standard camera capture';

  @override
  String get scanDocument => 'Scan Document';

  @override
  String get scanDocumentSubtitle => 'Scan with edge detection';

  @override
  String get captureMenuTitle => 'Capture Method';

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
  String get delete => 'Delete';

  @override
  String get shareAll => 'Share All';

  @override
  String get reset => 'Reset';

  @override
  String get watermarkTypeText => 'Text';

  @override
  String get watermarkTypeImage => 'Image/Logo';

  @override
  String get selectWatermarkImage => 'Select Logo Image';

  @override
  String selectedWatermarkImage(String name) {
    return '$name';
  }

  @override
  String get watermarkTextLabel => 'Text to Stamp (+Date-time)';

  @override
  String get watermarkTextHint => 'Enter the text to stamp';

  @override
  String get color => 'Color';

  @override
  String transparencyValue(int value) {
    return 'Transparency: $value%';
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
  String logoSizeLabel(int value) {
    return 'Logo Size: ${value}px';
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
  String get imageResizingEnabledHint => 'Image resizing is enabled';

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
  String get preserveMetadataEnabledHint => 'File metadata will be preserved';

  @override
  String get rasterizePdfTitle => 'Rasterize PDF (Flatten)';

  @override
  String get rasterizePdfSubtitle =>
      'Convert PDF pages to images for maximum security (bigger size and slower)';

  @override
  String get rasterizePdfEnabledHint => 'PDF will be rasterized (flattened)';

  @override
  String get pdfSecurityTitle => 'PDF Advanced Security';

  @override
  String get enablePdfSecurity => 'Enable PDF Security';

  @override
  String get pdfSecuritySubtitle =>
      'Protect PDF with passwords and restrict permissions';

  @override
  String get pdfUserPasswordLabel => 'User Password (to open)';

  @override
  String get pdfUserPasswordHint => 'Password required to view the PDF';

  @override
  String get pdfOwnerPasswordLabel => 'Owner Password (to restrict)';

  @override
  String get pdfOwnerPasswordHint => 'Password required to change permissions';

  @override
  String get pdfAllowPrinting => 'Allow Printing';

  @override
  String get pdfAllowCopying => 'Allow Text/Content Copying';

  @override
  String get pdfAllowEditing => 'Allow Annotations/Editing';

  @override
  String get pdfSecurityNote =>
      'Note: Security settings only apply to PDF files and depend on viewer support.';

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
  String get fontConfigTitle => 'Font Configuration';

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
  String logoDirectoryLabel(String path) {
    return 'Logo Directory: $path';
  }

  @override
  String get selectLogoDirectory => 'Select Logo Directory';

  @override
  String get viewLogs => 'View Logs';

  @override
  String get saveLogs => 'Save Logs';

  @override
  String logsSaved(String path) {
    return 'Logs saved to: $path';
  }

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
  String get analyzeFile => 'Analyze File';

  @override
  String get fileAnalyzerTitle => 'File Analyzer';

  @override
  String get fileAnalyzerDescription =>
      'Select a file to check for hidden SecureMark signatures.';

  @override
  String get pickAndAnalyze => 'Pick and Analyze';

  @override
  String encryptedFileDetected(String name) {
    return '🔐 Encrypted file detected: $name. Please provide the correct password.';
  }

  @override
  String hiddenFileDetected(String name, String size) {
    return '📁 Hidden file detected: $name ($size)';
  }

  @override
  String get encryptedSignatureDetected =>
      '🔐 Encrypted signature detected. Please provide the correct password.';

  @override
  String signatureFound(String message) {
    return '✅ Signature found: \"$message\"';
  }

  @override
  String robustSignatureFound(String message) {
    return '💪 Robust signature found: \"$message\"';
  }

  @override
  String get missingSteganographySignature =>
      'Custom Steganography Signature cannot be empty when steganography is enabled.';

  @override
  String get missingQrContent =>
      'QR code content cannot be empty when QR code is enabled.';

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
  String get hideFileEnabledHint => 'A hidden file will be embedded';

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
  String get steganographyZipNote =>
      'Important: If you use steganography and share these files via WhatsApp, Signal, or other apps that compress images, you must enable ZIP compression or ZIP them manually. Direct sharing usually destroys the invisible steganography.';

  @override
  String get steganographyImageOnlyNote =>
      'Note: Steganography (invisible signatures and hidden files) is only supported for image files (JPG, PNG, WebP). It will be skipped for PDF files.';

  @override
  String get steganographyTextLabel => 'Custom Steganography Signature';

  @override
  String get steganographyTextHint =>
      'Enter custom text to hide (defaults to watermark text if empty)';

  @override
  String get zipAllFiles => 'ZIP All Files';

  @override
  String get secureZipTitle => 'Secure ZIP Archive';

  @override
  String get enableSecureZip => 'Enable AES-256 Encryption';

  @override
  String get secureZipPasswordLabel => 'ZIP Password';

  @override
  String get secureZipPasswordHint => 'Password to extract the ZIP archive';

  @override
  String get zipEnabledHint =>
      'ZIP compression enabled for sharing. NOTE: third‑party apps (WhatsApp, Signal, etc.) compress images, potentially destroying steganographic signatures. Enable ZIP to avoid loosing signatures.';

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
  String receivedFilesFromSharing(int count) {
    return '📥 Received $count file(s) from sharing';
  }

  @override
  String get unsupportedSharedFormat =>
      '⚠️ Shared files are not in a supported format (JPG, PNG, WebP, PDF, HEIC/HEIF)';

  @override
  String get signatureCopied => 'Signature copied to clipboard';

  @override
  String get copySignature => 'Copy signature';

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
    return 'Anti-AI Removal Protection: $value%';
  }

  @override
  String get antiAiProtectionNote =>
      'Note: adds jitter and noise to make the watermark much harder to remove by AI. Higher levels take more time.';

  @override
  String get antiAiEnabledHint => 'Anti-AI removal protection is enabled';

  @override
  String get antiAiProtectionTitle => 'Anti-AI Removal Protection';

  @override
  String get antiAiProtectionSubtitle =>
      'Adds jitter and noise to make watermarks harder to remove by AI';

  @override
  String get aiCloakingTitle => 'AI Cloaking (Adversarial)';

  @override
  String get aiCloakingSubtitle =>
      'Injects invisible adversarial noise to disrupt AI training and style theft.';

  @override
  String get aiCloakingEnabledHint => 'AI Cloaking is active';

  @override
  String get digitallySignTitle => 'Digital Integrity Signature';

  @override
  String get digitallySignSubtitle =>
      'Sign document with device key to prove it hasn\'t been modified.';

  @override
  String get digitallySignEnabledHint => 'Digital signature will be applied';

  @override
  String get myIdentityTitle => 'My Device Identity';

  @override
  String get deviceNameLabel => 'Device / Owner Name';

  @override
  String get identityNameLabel => 'Name';

  @override
  String get myPublicKeyLabel => 'Public Key (Your Digital ID):';

  @override
  String get copyPublicKey => 'Copy Public Key';

  @override
  String get sharePublicKey => 'Share Public Key';

  @override
  String get generateQrKey => 'Generate QR Code';

  @override
  String get qrIdentityTitle => 'Identity QR Code';

  @override
  String get publicKeyCopied => 'Public key copied to clipboard';

  @override
  String get bookmarkSaved => 'Identity bookmarked successfully';

  @override
  String get signatureVerified => '✅ Integrity Verified: Document is authentic';

  @override
  String get tamperDetected => '❌ TAMPER DETECTED: Document has been modified';

  @override
  String senderOwnerLabel(String name) {
    return 'Sender: $name';
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
  String get processingErrorsTitle => 'Processing Errors';

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

  @override
  String get fileTooLargeTitle => 'File Too Large';

  @override
  String fileTooLargeMessage(String fileName, String fileSize,
      String imageDimensions, String maxCapacity) {
    return 'The file \"$fileName\" ($fileSize KB) is too large to hide in this image ($imageDimensions).\n\nMaximum capacity: $maxCapacity KB\n\nPlease use a larger image or compress/reduce the file size.';
  }

  @override
  String get loadingSelectedFiles => 'Loading Selected Files...';

  @override
  String get profileLabel => 'Profile';

  @override
  String get profileDescription => 'Quick presets for common use cases';

  @override
  String get profileNone => 'Custom';

  @override
  String get profileSecureIdentity => 'Identity';

  @override
  String get profileOnlineImage => 'Image';

  @override
  String get profileQrCode => 'QR Code';

  @override
  String get profileShareDocument => 'Doc';

  @override
  String get progressValidating => 'Validating file...';

  @override
  String get progressFromCache => 'Retrieved from cache';

  @override
  String get progressDetectingType => 'Detecting file type...';

  @override
  String get progressStarting => 'Starting processing...';

  @override
  String get progressComplete => 'Processing complete';

  @override
  String get progressReadingImage => 'Reading image file...';

  @override
  String get progressRenderingFont => 'Rendering font...';

  @override
  String get progressFinalizingImage => 'Finalizing image...';

  @override
  String get progressVerifyingStegano => 'Verifying steganography...';

  @override
  String get progressSteganoVerified => 'Steganography verified';

  @override
  String get progressSteganoFailed => 'Steganography verification failed';

  @override
  String get progressRasterizing => 'Rasterizing PDF (flattening)...';

  @override
  String get progressReadingPdf => 'Reading PDF file...';

  @override
  String get progressAddingLayer => 'Adding watermark layer...';

  @override
  String get progressFinalizingPdf => 'Finalizing PDF...';

  @override
  String get progressSigningPdf => 'Digitally signing PDF...';

  @override
  String get progressParsingPdf => 'Parsing PDF document...';

  @override
  String get progressDecodingImage => 'Decoding image...';

  @override
  String get progressResizingImage => 'Resizing image...';

  @override
  String get progressApplyingCloaking => 'Applying adversarial AI cloaking...';

  @override
  String get progressApplyingWatermark => 'Applying watermark...';

  @override
  String get progressEmbeddingRobust => 'Embedding robust watermark (DCT)...';

  @override
  String get progressHidingFile => 'Hiding file in image (steganography)...';

  @override
  String get progressEmbeddingLsb => 'Embedding invisible signature (LSB)...';

  @override
  String get progressEncodingImage => 'Encoding image...';

  @override
  String get progressGeneratingQr => 'Generating QR code...';

  @override
  String get progressEmbeddingQr => 'Embedding QR code...';

  @override
  String get progressQrEmbedded => 'QR code embedded';

  @override
  String progressWatermarkingPage(int current, int total) {
    return 'Watermarking page $current/$total...';
  }

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAmoled => 'Amoled Black';

  @override
  String get resetProfiles => 'Reset Profiles';

  @override
  String resetProfileConfirm(String profile) {
    return 'Reset $profile to factory defaults?';
  }

  @override
  String profileSaved(String profile) {
    return 'Current configuration saved as default for $profile';
  }

  @override
  String profileReset(String profile) {
    return 'Profile $profile reset to factory defaults';
  }

  @override
  String get previewModeOriginal => 'Original';

  @override
  String get previewModeProcessed => 'Processed';

  @override
  String get previewModeHeatmap => 'Tamper Heatmap';

  @override
  String get authenticityVerified => 'AUTHENTICITY VERIFIED';

  @override
  String get fullAuthenticityConfirmed => 'FULL AUTHENTICITY CONFIRMED';

  @override
  String get partialAuthenticity => 'PARTIAL AUTHENTICITY';

  @override
  String get tamperingDetected => 'TAMPERING DETECTED';

  @override
  String get forensicLayerContent => 'Content (Image + Hidden Data)';

  @override
  String get forensicLayerSource => 'Source (Visible Image)';

  @override
  String get forensicStatusValid => 'VALID';

  @override
  String get forensicStatusModified => 'MODIFIED';

  @override
  String get verifFullIntegrity =>
      'Full integrity confirmed (Image + Hidden Data).';

  @override
  String get verifPartialIntegrity =>
      'Visual integrity confirmed, but hidden steganography has been modified or corrupted.';

  @override
  String get verifTamperingDetected =>
      'Forensic check failed. Both visual pixels and hidden data appear modified.';

  @override
  String get onboardingStepTitle => 'How it works';

  @override
  String get onboardingStep1 => '1. Choose a Profile preset for your use case.';

  @override
  String get onboardingStep2 => '2. Import your Images or PDF files.';

  @override
  String get onboardingStep2NoCamera => '2. Pick your Images or PDF files.';

  @override
  String get onboardingStep3 => '3. Click Apply to generate the watermarks.';

  @override
  String get onboardingStep4 => '4. Share or Save the results.';

  @override
  String get onboardingExpertTitle => 'Profiles & Options';

  @override
  String get onboardingExpertModeTitle => 'Expert Mode';

  @override
  String get onboardingSaveProfileTitle => 'Save Presets';

  @override
  String get onboardingLiveStatusTitle => 'Security Status';

  @override
  String get onboardingFileAnalyzerTitle => 'Verification';

  @override
  String get onboardingProfileSave =>
      'Long-press any profile to save your current configuration as the default for that preset.';

  @override
  String get onboardingExpertNote =>
      'Expert mode (top right) unlocks advanced settings';

  @override
  String get onboardingOptionsNote =>
      'Double-tap to enable or disable a feature, and long-press to configure its settings.';

  @override
  String get onboardingFileAnalyzerNote =>
      'File Analyzer to check for hidden SecureMark signature or files';

  @override
  String get watermarkCustomizationTitle => 'Watermark Customization';

  @override
  String get watermarkCustomizationSubtitle =>
      'Choose between Text or Logo, customize colors, and adjust density and opacity.';

  @override
  String get onboardingQrCodeNote =>
      'Embed contact info, links, or metadata via QR code.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingDone => 'Got it';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get showGuide => 'Show Guide';

  @override
  String get activeOptionsHelpTitle => 'Active Security Options';

  @override
  String get identityBookmarksTitle => 'Signature Contacts';

  @override
  String get bookmarkNameLabel => 'Identity Name';

  @override
  String get identityKeyLabel => 'Signature (public key)';

  @override
  String get addIdentity => 'Contact';

  @override
  String get addWithQrCode => 'QR Code';

  @override
  String get removeIdentityConfirm => 'Remove this identity bookmark?';

  @override
  String get invalidQrCode => 'Invalid identity QR code';

  @override
  String get scannerTitle => 'Scan Public Key QR';

  @override
  String get exportConfigTitle => 'Export Config & Keys';

  @override
  String get importConfigTitle => 'Import Config & Keys';

  @override
  String get exportConfigDesc =>
      'This will create a password-protected ZIP with all your settings and digital identity keys.';

  @override
  String get exportConfigButton => 'Export';

  @override
  String get importConfigButton => 'Import';

  @override
  String configExportSuccess(Object path) {
    return 'Configuration exported successfully to: $path';
  }

  @override
  String get longPressToConfigure => 'Long-press to configure';

  @override
  String get longPressConfigure => 'Long-press: configure';

  @override
  String get noBookmarksYet => 'No bookmarks yet.';

  @override
  String get statusEnabled => 'Status: Enabled';

  @override
  String get statusDisabled => 'Status: Disabled';

  @override
  String get doubleTapToToggle => 'Double-tap to toggle';

  @override
  String get requiresSteganography => 'Requires steganography';

  @override
  String get unavailableRasterPdf => 'Not compatible with PDF Rasterization';

  @override
  String get preserveMetadata => 'Preserve Metadata';

  @override
  String get tapInfo => 'Tap: info';

  @override
  String get doubleTapToggle => 'Double-tap: toggle';

  @override
  String get tapInfoDoubleTapToggle => 'Tap: info • Double-tap: toggle';

  @override
  String statusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get enabled => 'enabled';

  @override
  String get disabled => 'disabled';

  @override
  String get localShareTitle => 'Local Network Share';

  @override
  String get sendTab => 'Send';

  @override
  String get receiveTab => 'Receive/Send';

  @override
  String sendingFile(Object name) {
    return 'Sending: $name';
  }

  @override
  String get noFilesToSend => 'Process some files first to send them.';

  @override
  String get receivingFile => 'Receiving File';

  @override
  String get connectingToServer => 'Connecting to sender...';

  @override
  String downloadingFile(Object name) {
    return 'Downloading: $name';
  }

  @override
  String get saveToWhere => 'Save file to...';

  @override
  String get localShareInstructions =>
      'The receiver must be on the same network. Scan the QR code to download.';

  @override
  String get sendAllZip => 'Send All as ZIP';

  @override
  String get randomColorSelected => 'Random color selected';

  @override
  String get uniqueColorSelected => 'Unique color selected';

  @override
  String get densityLabel => 'DENSITY';

  @override
  String get opacityLabel => 'OPACITY';

  @override
  String get generatingKey => 'Generating encryption key...';

  @override
  String get encryptingPayload => 'Encrypting payload (AES-256)...';

  @override
  String get startingServer => 'Starting local HTTP server...';

  @override
  String get decryptingPayload => 'Decrypting data...';

  @override
  String get payloadEncrypted => 'Data encrypted and secured';

  @override
  String get connectionEstablished => 'Connected to sender';

  @override
  String serverStarted(Object port) {
    return 'Server running on port $port';
  }

  @override
  String get enableEncryption => 'Use End-to-End Encryption';

  @override
  String downloadSpeed(Object speed) {
    return 'Speed: $speed';
  }

  @override
  String get pickAnyFile => 'Pick Custom File';

  @override
  String get encryptionDisabledWarning =>
      'Warning: Data will be sent unencrypted on the local network.';

  @override
  String get noCameraOption => 'No camera? Show QR to receive';

  @override
  String get showQrToReceive =>
      'Scan this from the sending device to push a file here.';

  @override
  String pushingFile(Object device) {
    return 'Pushing file to $device...';
  }

  @override
  String get manualUrlLabel => 'Or enter this URL in a browser:';

  @override
  String get waitingForFile => 'Waiting for incoming file...';

  @override
  String fileReceived(Object address) {
    return 'File received from $address';
  }
}
