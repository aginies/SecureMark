import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('it')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SecureMark'**
  String get appTitle;

  /// No description provided for @emptyPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Enter watermark text and pick one or more image or PDF files'**
  String get emptyPreviewHint;

  /// No description provided for @selectedPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Files selected. Click Apply SecureMark to generate previews'**
  String get selectedPreviewHint;

  /// No description provided for @selectedFilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected Files ({count})'**
  String selectedFilesLabel(int count);

  /// No description provided for @clickApplyToPreview.
  ///
  /// In en, this message translates to:
  /// **'Click \"Apply SecureMark\" to generate previews'**
  String get clickApplyToPreview;

  /// No description provided for @previewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get previewUnavailable;

  /// No description provided for @swipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left for next, right for previous ({current}/{total})'**
  String swipeHint(int current, int total);

  /// No description provided for @processingFile.
  ///
  /// In en, this message translates to:
  /// **'Processing file...'**
  String get processingFile;

  /// No description provided for @applyingWatermark.
  ///
  /// In en, this message translates to:
  /// **'Applying watermark...'**
  String get applyingWatermark;

  /// No description provided for @processingValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating file...'**
  String get processingValidating;

  /// No description provided for @processingProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing file...'**
  String get processingProcessing;

  /// No description provided for @processingCached.
  ///
  /// In en, this message translates to:
  /// **'Retrieved from cache'**
  String get processingCached;

  /// No description provided for @processingComplete.
  ///
  /// In en, this message translates to:
  /// **'Processing complete'**
  String get processingComplete;

  /// No description provided for @processingFlattening.
  ///
  /// In en, this message translates to:
  /// **'Rasterizing PDF (flattening)...'**
  String get processingFlattening;

  /// No description provided for @authorFooter.
  ///
  /// In en, this message translates to:
  /// **'Author: Antoine Giniès'**
  String get authorFooter;

  /// No description provided for @pickFiles.
  ///
  /// In en, this message translates to:
  /// **'Images or PDF'**
  String get pickFiles;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @takePhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Camera direct use'**
  String get takePhotoSubtitle;

  /// No description provided for @selectedFile.
  ///
  /// In en, this message translates to:
  /// **'Selected file: {name}'**
  String selectedFile(String name);

  /// No description provided for @selectedFiles.
  ///
  /// In en, this message translates to:
  /// **'Selected files: {count}'**
  String selectedFiles(int count);

  /// No description provided for @applyWatermark.
  ///
  /// In en, this message translates to:
  /// **'Apply SecureMark'**
  String get applyWatermark;

  /// No description provided for @saveAll.
  ///
  /// In en, this message translates to:
  /// **'Save All'**
  String get saveAll;

  /// No description provided for @shareAll.
  ///
  /// In en, this message translates to:
  /// **'Share All'**
  String get shareAll;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @watermarkTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get watermarkTypeText;

  /// No description provided for @watermarkTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image/Logo'**
  String get watermarkTypeImage;

  /// No description provided for @selectWatermarkImage.
  ///
  /// In en, this message translates to:
  /// **'Select Logo Image'**
  String get selectWatermarkImage;

  /// No description provided for @selectedWatermarkImage.
  ///
  /// In en, this message translates to:
  /// **'Logo: {name}'**
  String selectedWatermarkImage(String name);

  /// No description provided for @watermarkTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Text to Stamp (+Date-time)'**
  String get watermarkTextLabel;

  /// No description provided for @watermarkTextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the text to stamp'**
  String get watermarkTextHint;

  /// No description provided for @randomColor.
  ///
  /// In en, this message translates to:
  /// **'Random color'**
  String get randomColor;

  /// No description provided for @selectedColor.
  ///
  /// In en, this message translates to:
  /// **'Selected color'**
  String get selectedColor;

  /// No description provided for @transparencyValue.
  ///
  /// In en, this message translates to:
  /// **'Watermark Transparency: {value}%'**
  String transparencyValue(int value);

  /// No description provided for @densityValue.
  ///
  /// In en, this message translates to:
  /// **'Density: {value}%'**
  String densityValue(int value);

  /// No description provided for @droppedPathUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The dropped file paths are unavailable.'**
  String get droppedPathUnavailable;

  /// No description provided for @desktopDropArea.
  ///
  /// In en, this message translates to:
  /// **'Drop Files Here'**
  String get desktopDropArea;

  /// No description provided for @pickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Images and PDFs'**
  String get pickerLabel;

  /// No description provided for @processingCount.
  ///
  /// In en, this message translates to:
  /// **'Processing 1/{count} files...'**
  String processingCount(int count);

  /// No description provided for @processingNamedFile.
  ///
  /// In en, this message translates to:
  /// **'Processing {current}/{total}: {name}'**
  String processingNamedFile(int current, int total, String name);

  /// No description provided for @processingFailed.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file or processing failed.'**
  String get processingFailed;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(String error);

  /// No description provided for @savedFiles.
  ///
  /// In en, this message translates to:
  /// **'Saved {count, plural, one {1 file} other {{count} files}}.'**
  String savedFiles(int count);

  /// No description provided for @shareSubject.
  ///
  /// In en, this message translates to:
  /// **'Watermarked files'**
  String get shareSubject;

  /// No description provided for @shareText.
  ///
  /// In en, this message translates to:
  /// **'Shared from SecureMark'**
  String get shareText;

  /// No description provided for @sharedFiles.
  ///
  /// In en, this message translates to:
  /// **'Shared {count, plural, one {1 file} other {{count} files}}.'**
  String sharedFiles(int count);

  /// No description provided for @shareOpenedFiles.
  ///
  /// In en, this message translates to:
  /// **'Share sheet opened for {count, plural, one {1 file} other {{count} files}}.'**
  String shareOpenedFiles(int count);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @saveLocationInfo.
  ///
  /// In en, this message translates to:
  /// **'Files will be saved in the same folder as originals with \'securemark-\' prefix'**
  String get saveLocationInfo;

  /// No description provided for @expertOptions.
  ///
  /// In en, this message translates to:
  /// **'Expert Options'**
  String get expertOptions;

  /// No description provided for @fontSizeValue.
  ///
  /// In en, this message translates to:
  /// **'Font Size: {value}px'**
  String fontSizeValue(int value);

  /// No description provided for @logoSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Logo Size: {value}px'**
  String logoSizeLabel(int value);

  /// No description provided for @jpegQualityValue.
  ///
  /// In en, this message translates to:
  /// **'JPEG Quality: {value}%'**
  String jpegQualityValue(int value);

  /// No description provided for @imageResizingLabel.
  ///
  /// In en, this message translates to:
  /// **'Image Resizing: {size}'**
  String imageResizingLabel(String size);

  /// No description provided for @imageResizingEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Image resizing is enabled'**
  String get imageResizingEnabledHint;

  /// No description provided for @resizeNone.
  ///
  /// In en, this message translates to:
  /// **'None (Original)'**
  String get resizeNone;

  /// No description provided for @pixelUnit.
  ///
  /// In en, this message translates to:
  /// **'{value} px'**
  String pixelUnit(int value);

  /// No description provided for @includeTimestampFilename.
  ///
  /// In en, this message translates to:
  /// **'Include Date & Hour in Filename'**
  String get includeTimestampFilename;

  /// No description provided for @preserveExifData.
  ///
  /// In en, this message translates to:
  /// **'Preserve File Metadata (EXIF/PDF Info)'**
  String get preserveExifData;

  /// No description provided for @preserveMetadataEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'File metadata will be preserved'**
  String get preserveMetadataEnabledHint;

  /// No description provided for @rasterizePdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Rasterize PDF (Flatten)'**
  String get rasterizePdfTitle;

  /// No description provided for @rasterizePdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Convert PDF pages to images for maximum security (bigger size and slower)'**
  String get rasterizePdfSubtitle;

  /// No description provided for @rasterizePdfEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'PDF will be rasterized (flattened)'**
  String get rasterizePdfEnabledHint;

  /// No description provided for @steganographyTitle.
  ///
  /// In en, this message translates to:
  /// **'Steganography (Invisible Signature)'**
  String get steganographyTitle;

  /// No description provided for @steganographySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Embed text secretly in pixels.'**
  String get steganographySubtitle;

  /// No description provided for @robustSteganographyTitle.
  ///
  /// In en, this message translates to:
  /// **'Robust Watermarking (DCT Domain)'**
  String get robustSteganographyTitle;

  /// No description provided for @robustSteganographySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Experimental: Survives re-compression and resizing better than LSB.'**
  String get robustSteganographySubtitle;

  /// No description provided for @filePrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'File Prefix'**
  String get filePrefixLabel;

  /// No description provided for @filePrefixHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., watermark-'**
  String get filePrefixHint;

  /// No description provided for @resetExpertHint.
  ///
  /// In en, this message translates to:
  /// **'This will reset all expert settings and file prefix to defaults.'**
  String get resetExpertHint;

  /// No description provided for @fontStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Font Style'**
  String get fontStyleLabel;

  /// No description provided for @fontSelectionNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Using optimized bitmap fonts for fast cross-platform rendering.'**
  String get fontSelectionNote;

  /// No description provided for @fontSelectionNoteGoogle.
  ///
  /// In en, this message translates to:
  /// **'Note: Using Google Fonts for enhanced typography. Requires internet for first use.'**
  String get fontSelectionNoteGoogle;

  /// No description provided for @fontSelectionNoteAsset.
  ///
  /// In en, this message translates to:
  /// **'Note: Using custom TTF font for enhanced typography. Requires font files in assets/fonts/.'**
  String get fontSelectionNoteAsset;

  /// No description provided for @resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get resetToDefaults;

  /// No description provided for @outputDirectoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Output Directory: {path}'**
  String outputDirectoryLabel(String path);

  /// No description provided for @selectOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select Output Directory'**
  String get selectOutputDirectory;

  /// No description provided for @viewLogs.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get viewLogs;

  /// No description provided for @saveLogs.
  ///
  /// In en, this message translates to:
  /// **'Save Logs'**
  String get saveLogs;

  /// No description provided for @logsSaved.
  ///
  /// In en, this message translates to:
  /// **'Logs saved to: {path}'**
  String logsSaved(String path);

  /// No description provided for @appLogs.
  ///
  /// In en, this message translates to:
  /// **'App Logs'**
  String get appLogs;

  /// No description provided for @noLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get noLogsYet;

  /// No description provided for @openGitHub.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub Repository'**
  String get openGitHub;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About SecureMark'**
  String get aboutApp;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'A professional application to secure documents with watermarks for safe sharing.'**
  String get appDescription;

  /// No description provided for @authorLabel.
  ///
  /// In en, this message translates to:
  /// **'Author: {name}'**
  String authorLabel(String name);

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checkingForUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version.'**
  String get upToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version ({version}) is available!'**
  String updateAvailable(String version);

  /// No description provided for @updateCheckError.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates.'**
  String get updateCheckError;

  /// No description provided for @githubRepository.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get githubRepository;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @viewUpdate.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewUpdate;

  /// No description provided for @analyzeFile.
  ///
  /// In en, this message translates to:
  /// **'Analyze File (LSB)'**
  String get analyzeFile;

  /// No description provided for @fileAnalyzerTitle.
  ///
  /// In en, this message translates to:
  /// **'File Analyzer (LSB)'**
  String get fileAnalyzerTitle;

  /// No description provided for @fileAnalyzerDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a file to check for hidden SecureMark signatures.'**
  String get fileAnalyzerDescription;

  /// No description provided for @pickAndAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Pick and Analyze'**
  String get pickAndAnalyze;

  /// No description provided for @encryptedFileDetected.
  ///
  /// In en, this message translates to:
  /// **'🔐 Encrypted file detected: {name}. Please provide the correct password.'**
  String encryptedFileDetected(Object name);

  /// No description provided for @hiddenFileDetected.
  ///
  /// In en, this message translates to:
  /// **'📁 Hidden file detected: {name} ({size})'**
  String hiddenFileDetected(Object name, Object size);

  /// No description provided for @encryptedSignatureDetected.
  ///
  /// In en, this message translates to:
  /// **'🔐 Encrypted signature detected. Please provide the correct password.'**
  String get encryptedSignatureDetected;

  /// No description provided for @signatureFound.
  ///
  /// In en, this message translates to:
  /// **'✅ Signature found: \"{message}\"'**
  String signatureFound(String message);

  /// No description provided for @robustSignatureFound.
  ///
  /// In en, this message translates to:
  /// **'💪 Robust signature found: \"{message}\"'**
  String robustSignatureFound(String message);

  /// No description provided for @noSignatureFound.
  ///
  /// In en, this message translates to:
  /// **'❌ No SecureMark signature detected in this file.'**
  String get noSignatureFound;

  /// No description provided for @analysisError.
  ///
  /// In en, this message translates to:
  /// **'Error during analysis: {error}'**
  String analysisError(String error);

  /// No description provided for @analysisResult.
  ///
  /// In en, this message translates to:
  /// **'Result:'**
  String get analysisResult;

  /// No description provided for @steganographyVerified.
  ///
  /// In en, this message translates to:
  /// **'Steganography Verified'**
  String get steganographyVerified;

  /// No description provided for @steganographyVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Steganography verification failed'**
  String get steganographyVerificationFailed;

  /// No description provided for @steganographyEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Steganography is enabled and will be applied'**
  String get steganographyEnabledHint;

  /// No description provided for @hideFileWithSteganographyTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide a file (experimental)'**
  String get hideFileWithSteganographyTitle;

  /// No description provided for @hideFileWithSteganographySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Embed an entire file within the image (might increase output size)'**
  String get hideFileWithSteganographySubtitle;

  /// No description provided for @hideFileEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'A hidden file will be embedded'**
  String get hideFileEnabledHint;

  /// No description provided for @selectFileToHide.
  ///
  /// In en, this message translates to:
  /// **'Select File to Hide'**
  String get selectFileToHide;

  /// No description provided for @selectedHiddenFile.
  ///
  /// In en, this message translates to:
  /// **'Hidden file: {name}'**
  String selectedHiddenFile(String name);

  /// No description provided for @hiddenFileSecurityWarning.
  ///
  /// In en, this message translates to:
  /// **'Security Notice: Hidden files are only secure if encrypted before embedding. Steganography obscures but does not encrypt your data.'**
  String get hiddenFileSecurityWarning;

  /// No description provided for @steganographyPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Encryption Password'**
  String get steganographyPasswordLabel;

  /// No description provided for @steganographyPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password to protect hidden file'**
  String get steganographyPasswordHint;

  /// No description provided for @steganographyPasswordNote.
  ///
  /// In en, this message translates to:
  /// **'Note: This password will be required to extract the hidden file using SecureMark. It uses AES-256 encryption.'**
  String get steganographyPasswordNote;

  /// No description provided for @zipAllFiles.
  ///
  /// In en, this message translates to:
  /// **'ZIP All Files'**
  String get zipAllFiles;

  /// No description provided for @zipEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'ZIP compression enabled for sharing'**
  String get zipEnabledHint;

  /// No description provided for @zipDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'ZIP compression disabled'**
  String get zipDisabledHint;

  /// No description provided for @qrWatermarkTitle.
  ///
  /// In en, this message translates to:
  /// **'QR Code Watermark'**
  String get qrWatermarkTitle;

  /// No description provided for @enableQrWatermark.
  ///
  /// In en, this message translates to:
  /// **'Enable QR Code'**
  String get enableQrWatermark;

  /// No description provided for @enableQrWatermarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Embed metadata in a QR code'**
  String get enableQrWatermarkSubtitle;

  /// No description provided for @qrMode.
  ///
  /// In en, this message translates to:
  /// **'QR Code Mode'**
  String get qrMode;

  /// No description provided for @qrVisibleMode.
  ///
  /// In en, this message translates to:
  /// **'Visible QR Code'**
  String get qrVisibleMode;

  /// No description provided for @qrVisibleModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Show QR code on the image'**
  String get qrVisibleModeDesc;

  /// No description provided for @qrAuthorLabel.
  ///
  /// In en, this message translates to:
  /// **'Author Name'**
  String get qrAuthorLabel;

  /// No description provided for @qrAuthorHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., John Doe'**
  String get qrAuthorHint;

  /// No description provided for @qrUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL or Website'**
  String get qrUrlLabel;

  /// No description provided for @qrUrlHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., https://example.com'**
  String get qrUrlHint;

  /// No description provided for @qrVisibleOptions.
  ///
  /// In en, this message translates to:
  /// **'Visible QR Options'**
  String get qrVisibleOptions;

  /// No description provided for @qrPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'QR Code Position'**
  String get qrPositionLabel;

  /// No description provided for @qrPosTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Top Left'**
  String get qrPosTopLeft;

  /// No description provided for @qrPosTopRight.
  ///
  /// In en, this message translates to:
  /// **'Top Right'**
  String get qrPosTopRight;

  /// No description provided for @qrPosBottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom Left'**
  String get qrPosBottomLeft;

  /// No description provided for @qrPosBottomRight.
  ///
  /// In en, this message translates to:
  /// **'Bottom Right'**
  String get qrPosBottomRight;

  /// No description provided for @qrPosCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get qrPosCenter;

  /// No description provided for @qrSizeValue.
  ///
  /// In en, this message translates to:
  /// **'QR Code Size: {value}px'**
  String qrSizeValue(int value);

  /// No description provided for @qrOpacityValue.
  ///
  /// In en, this message translates to:
  /// **'QR Code Opacity: {value}%'**
  String qrOpacityValue(int value);

  /// No description provided for @receivedFilesFromSharing.
  ///
  /// In en, this message translates to:
  /// **'📥 Received {count} file(s) from sharing'**
  String receivedFilesFromSharing(int count);

  /// No description provided for @unsupportedSharedFormat.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Shared files are not in a supported format (JPG, PNG, WebP, PDF, HEIC/HEIF)'**
  String get unsupportedSharedFormat;

  /// No description provided for @signatureCopied.
  ///
  /// In en, this message translates to:
  /// **'Signature copied to clipboard'**
  String get signatureCopied;

  /// No description provided for @copySignature.
  ///
  /// In en, this message translates to:
  /// **'Copy signature'**
  String get copySignature;

  /// No description provided for @saveHiddenFile.
  ///
  /// In en, this message translates to:
  /// **'Save Hidden File'**
  String get saveHiddenFile;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved: {name}'**
  String fileSaved(String name);

  /// No description provided for @errorSavingFile.
  ///
  /// In en, this message translates to:
  /// **'Error saving file: {error}'**
  String errorSavingFile(String error);

  /// No description provided for @antiAiProtectionValue.
  ///
  /// In en, this message translates to:
  /// **'Anti-AI Protection: {value}%'**
  String antiAiProtectionValue(int value);

  /// No description provided for @antiAiProtectionNote.
  ///
  /// In en, this message translates to:
  /// **'Note: higher protection significantly increases the time to generate the securemarked image.'**
  String get antiAiProtectionNote;

  /// No description provided for @antiAiEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Anti-AI protection is enabled'**
  String get antiAiEnabledHint;

  /// No description provided for @aiCloakingTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Cloaking (Adversarial)'**
  String get aiCloakingTitle;

  /// No description provided for @aiCloakingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Injects invisible adversarial noise to disrupt AI training and style theft.'**
  String get aiCloakingSubtitle;

  /// No description provided for @aiCloakingEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'AI Cloaking is active'**
  String get aiCloakingEnabledHint;

  /// No description provided for @qrContentType.
  ///
  /// In en, this message translates to:
  /// **'QR Content Type'**
  String get qrContentType;

  /// No description provided for @qrTypeMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata (JSON)'**
  String get qrTypeMetadata;

  /// No description provided for @qrTypeUrl.
  ///
  /// In en, this message translates to:
  /// **'Website Redirect'**
  String get qrTypeUrl;

  /// No description provided for @qrTypeVCard.
  ///
  /// In en, this message translates to:
  /// **'Contact (vCard)'**
  String get qrTypeVCard;

  /// No description provided for @vCardFirstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get vCardFirstName;

  /// No description provided for @vCardLastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get vCardLastName;

  /// No description provided for @vCardPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get vCardPhone;

  /// No description provided for @vCardEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get vCardEmail;

  /// No description provided for @vCardOrg.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get vCardOrg;

  /// No description provided for @invalidUrlError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL (e.g., https://example.com)'**
  String get invalidUrlError;

  /// No description provided for @noQrFound.
  ///
  /// In en, this message translates to:
  /// **'❌ No QR code detected'**
  String get noQrFound;

  /// No description provided for @abToggleTooltipOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show Original'**
  String get abToggleTooltipOriginal;

  /// No description provided for @abToggleTooltipProcessed.
  ///
  /// In en, this message translates to:
  /// **'Show Processed'**
  String get abToggleTooltipProcessed;

  /// No description provided for @processingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Processing cancelled'**
  String get processingCancelled;

  /// No description provided for @processingStatusMultiple.
  ///
  /// In en, this message translates to:
  /// **'Processed {successCount} files successfully. {failedCount} files failed.'**
  String processingStatusMultiple(int successCount, int failedCount);

  /// No description provided for @processingFailedSingle.
  ///
  /// In en, this message translates to:
  /// **'Failed to process file. Please check the file format and try again.'**
  String get processingFailedSingle;

  /// No description provided for @processingFailedMultiple.
  ///
  /// In en, this message translates to:
  /// **'Failed to process {count} files. Please check the file formats and try again.'**
  String processingFailedMultiple(int count);

  /// No description provided for @fileSavedTo.
  ///
  /// In en, this message translates to:
  /// **'File saved to: {path}'**
  String fileSavedTo(String path);

  /// No description provided for @saveFailedGeneral.
  ///
  /// In en, this message translates to:
  /// **'Failed to save files. Please check permissions and storage space.'**
  String get saveFailedGeneral;

  /// No description provided for @saveStatusMultiple.
  ///
  /// In en, this message translates to:
  /// **'Saved {successCount} files. {failedCount} files failed.'**
  String saveStatusMultiple(int successCount, int failedCount);

  /// No description provided for @filesSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Files Saved'**
  String get filesSavedTitle;

  /// No description provided for @successfullySavedCount.
  ///
  /// In en, this message translates to:
  /// **'Successfully saved {count, plural, one {1 file} other {{count} files}}:'**
  String successfullySavedCount(int count);

  /// No description provided for @failedSavedCount.
  ///
  /// In en, this message translates to:
  /// **'Failed to save {count, plural, one {1 file} other {{count} files}}:'**
  String failedSavedCount(int count);

  /// No description provided for @willSaveAsIn.
  ///
  /// In en, this message translates to:
  /// **'Will save as: {name} in {path}/'**
  String willSaveAsIn(String name, String path);

  /// No description provided for @willSaveMultipleIn.
  ///
  /// In en, this message translates to:
  /// **'Will save {count} files to: {path}/'**
  String willSaveMultipleIn(int count, String path);

  /// No description provided for @savingFiles.
  ///
  /// In en, this message translates to:
  /// **'Saving files...'**
  String get savingFiles;

  /// No description provided for @errorSavingFiles.
  ///
  /// In en, this message translates to:
  /// **'Error saving files: {error}'**
  String errorSavingFiles(String error);

  /// No description provided for @foregroundTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'SecureMark Processing'**
  String get foregroundTaskTitle;

  /// No description provided for @foregroundTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Showing progress of document watermarking'**
  String get foregroundTaskDescription;

  /// No description provided for @foregroundTaskUpdate.
  ///
  /// In en, this message translates to:
  /// **'Processing file {current} of {total}: {name}'**
  String foregroundTaskUpdate(int current, int total, String name);

  /// No description provided for @fileTooLargeTitle.
  ///
  /// In en, this message translates to:
  /// **'File Too Large'**
  String get fileTooLargeTitle;

  /// No description provided for @fileTooLargeMessage.
  ///
  /// In en, this message translates to:
  /// **'The file \"{fileName}\" ({fileSize} KB) is too large to hide in this image ({imageDimensions}).\n\nMaximum capacity: {maxCapacity} KB\n\nPlease use a larger image or compress/reduce the file size.'**
  String fileTooLargeMessage(String fileName, String fileSize,
      String imageDimensions, String maxCapacity);

  /// No description provided for @profileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileLabel;

  /// No description provided for @profileDescription.
  ///
  /// In en, this message translates to:
  /// **'Quick presets for common use cases'**
  String get profileDescription;

  /// No description provided for @profileNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get profileNone;

  /// No description provided for @profileSecureIdentity.
  ///
  /// In en, this message translates to:
  /// **'Secure Identity'**
  String get profileSecureIdentity;

  /// No description provided for @profileOnlineImage.
  ///
  /// In en, this message translates to:
  /// **'Online Image'**
  String get profileOnlineImage;

  /// No description provided for @profileQrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get profileQrCode;

  /// No description provided for @profileShareDocument.
  ///
  /// In en, this message translates to:
  /// **'Share Document'**
  String get profileShareDocument;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
