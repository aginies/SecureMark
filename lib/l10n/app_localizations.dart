import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
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
    Locale('es'),
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
  /// **'Standard camera capture'**
  String get takePhotoSubtitle;

  /// No description provided for @scanDocument.
  ///
  /// In en, this message translates to:
  /// **'Scan Document'**
  String get scanDocument;

  /// No description provided for @scanDocumentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan with edge detection'**
  String get scanDocumentSubtitle;

  /// No description provided for @captureMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Capture Method'**
  String get captureMenuTitle;

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
  /// **'{name}'**
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

  /// No description provided for @pdfSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF Advanced Security'**
  String get pdfSecurityTitle;

  /// No description provided for @enablePdfSecurity.
  ///
  /// In en, this message translates to:
  /// **'Enable PDF Security'**
  String get enablePdfSecurity;

  /// No description provided for @pdfSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Protect PDF with passwords and restrict permissions'**
  String get pdfSecuritySubtitle;

  /// No description provided for @pdfUserPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'User Password (to open)'**
  String get pdfUserPasswordLabel;

  /// No description provided for @pdfUserPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password required to view the PDF'**
  String get pdfUserPasswordHint;

  /// No description provided for @pdfOwnerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner Password (to restrict)'**
  String get pdfOwnerPasswordLabel;

  /// No description provided for @pdfOwnerPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password required to change permissions'**
  String get pdfOwnerPasswordHint;

  /// No description provided for @pdfAllowPrinting.
  ///
  /// In en, this message translates to:
  /// **'Allow Printing'**
  String get pdfAllowPrinting;

  /// No description provided for @pdfAllowCopying.
  ///
  /// In en, this message translates to:
  /// **'Allow Text/Content Copying'**
  String get pdfAllowCopying;

  /// No description provided for @pdfAllowEditing.
  ///
  /// In en, this message translates to:
  /// **'Allow Annotations/Editing'**
  String get pdfAllowEditing;

  /// No description provided for @pdfSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Security settings only apply to PDF files and depend on viewer support.'**
  String get pdfSecurityNote;

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

  /// No description provided for @logoDirectoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Logo Directory: {path}'**
  String logoDirectoryLabel(String path);

  /// No description provided for @selectLogoDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select Logo Directory'**
  String get selectLogoDirectory;

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
  String encryptedFileDetected(String name);

  /// No description provided for @hiddenFileDetected.
  ///
  /// In en, this message translates to:
  /// **'📁 Hidden file detected: {name} ({size})'**
  String hiddenFileDetected(String name, String size);

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

  /// No description provided for @steganographyZipNote.
  ///
  /// In en, this message translates to:
  /// **'Important: If you use steganography and share these files via WhatsApp, Signal, or other apps that compress images, you must enable ZIP compression or ZIP them manually. Direct sharing usually destroys the invisible steganography.'**
  String get steganographyZipNote;

  /// No description provided for @steganographyImageOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Steganography (invisible signatures and hidden files) is only supported for image files (JPG, PNG, WebP). It will be skipped for PDF files.'**
  String get steganographyImageOnlyNote;

  /// No description provided for @steganographyTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom Steganography Signature'**
  String get steganographyTextLabel;

  /// No description provided for @steganographyTextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter custom text to hide (defaults to watermark text if empty)'**
  String get steganographyTextHint;

  /// No description provided for @zipAllFiles.
  ///
  /// In en, this message translates to:
  /// **'ZIP All Files'**
  String get zipAllFiles;

  /// No description provided for @secureZipTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure ZIP Archive'**
  String get secureZipTitle;

  /// No description provided for @enableSecureZip.
  ///
  /// In en, this message translates to:
  /// **'Enable AES-256 Encryption'**
  String get enableSecureZip;

  /// No description provided for @secureZipPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'ZIP Password'**
  String get secureZipPasswordLabel;

  /// No description provided for @secureZipPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password to extract the ZIP archive'**
  String get secureZipPasswordHint;

  /// No description provided for @zipEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'ZIP compression enabled for sharing. NOTE: third‑party apps (WhatsApp, Signal, etc.) compress images, potentially destroying steganographic signatures. Enable ZIP to avoid loosing signatures.'**
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
  /// **'Anti-AI Removal Protection: {value}%'**
  String antiAiProtectionValue(int value);

  /// No description provided for @antiAiProtectionNote.
  ///
  /// In en, this message translates to:
  /// **'Note: adds jitter and noise to make the watermark much harder to remove by AI. Higher levels take more time.'**
  String get antiAiProtectionNote;

  /// No description provided for @antiAiEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Anti-AI removal protection is enabled'**
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

  /// No description provided for @digitallySignTitle.
  ///
  /// In en, this message translates to:
  /// **'Digital Integrity Signature'**
  String get digitallySignTitle;

  /// No description provided for @digitallySignSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign document with device key to prove it hasn\'t been modified.'**
  String get digitallySignSubtitle;

  /// No description provided for @digitallySignEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Digital signature will be applied'**
  String get digitallySignEnabledHint;

  /// No description provided for @myIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'My Device Identity'**
  String get myIdentityTitle;

  /// No description provided for @myPublicKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Public Key (Your Digital ID):'**
  String get myPublicKeyLabel;

  /// No description provided for @copyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Copy Public Key'**
  String get copyPublicKey;

  /// No description provided for @publicKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Public key copied to clipboard'**
  String get publicKeyCopied;

  /// No description provided for @signatureVerified.
  ///
  /// In en, this message translates to:
  /// **'✅ Integrity Verified: Document is authentic'**
  String get signatureVerified;

  /// No description provided for @tamperDetected.
  ///
  /// In en, this message translates to:
  /// **'❌ TAMPER DETECTED: Document has been modified'**
  String get tamperDetected;

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

  /// No description provided for @processingErrorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing Errors'**
  String get processingErrorsTitle;

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

  /// No description provided for @loadingSelectedFiles.
  ///
  /// In en, this message translates to:
  /// **'Loading Selected Files...'**
  String get loadingSelectedFiles;

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
  /// **'Custom'**
  String get profileNone;

  /// No description provided for @profileSecureIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get profileSecureIdentity;

  /// No description provided for @profileOnlineImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get profileOnlineImage;

  /// No description provided for @profileQrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get profileQrCode;

  /// No description provided for @profileShareDocument.
  ///
  /// In en, this message translates to:
  /// **'Doc'**
  String get profileShareDocument;

  /// No description provided for @progressValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating file...'**
  String get progressValidating;

  /// No description provided for @progressFromCache.
  ///
  /// In en, this message translates to:
  /// **'Retrieved from cache'**
  String get progressFromCache;

  /// No description provided for @progressDetectingType.
  ///
  /// In en, this message translates to:
  /// **'Detecting file type...'**
  String get progressDetectingType;

  /// No description provided for @progressStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting processing...'**
  String get progressStarting;

  /// No description provided for @progressComplete.
  ///
  /// In en, this message translates to:
  /// **'Processing complete'**
  String get progressComplete;

  /// No description provided for @progressReadingImage.
  ///
  /// In en, this message translates to:
  /// **'Reading image file...'**
  String get progressReadingImage;

  /// No description provided for @progressRenderingFont.
  ///
  /// In en, this message translates to:
  /// **'Rendering font...'**
  String get progressRenderingFont;

  /// No description provided for @progressFinalizingImage.
  ///
  /// In en, this message translates to:
  /// **'Finalizing image...'**
  String get progressFinalizingImage;

  /// No description provided for @progressVerifyingStegano.
  ///
  /// In en, this message translates to:
  /// **'Verifying steganography...'**
  String get progressVerifyingStegano;

  /// No description provided for @progressSteganoVerified.
  ///
  /// In en, this message translates to:
  /// **'Steganography verified'**
  String get progressSteganoVerified;

  /// No description provided for @progressSteganoFailed.
  ///
  /// In en, this message translates to:
  /// **'Steganography verification failed'**
  String get progressSteganoFailed;

  /// No description provided for @progressRasterizing.
  ///
  /// In en, this message translates to:
  /// **'Rasterizing PDF (flattening)...'**
  String get progressRasterizing;

  /// No description provided for @progressReadingPdf.
  ///
  /// In en, this message translates to:
  /// **'Reading PDF file...'**
  String get progressReadingPdf;

  /// No description provided for @progressAddingLayer.
  ///
  /// In en, this message translates to:
  /// **'Adding watermark layer...'**
  String get progressAddingLayer;

  /// No description provided for @progressFinalizingPdf.
  ///
  /// In en, this message translates to:
  /// **'Finalizing PDF...'**
  String get progressFinalizingPdf;

  /// No description provided for @progressSigningPdf.
  ///
  /// In en, this message translates to:
  /// **'Digitally signing PDF...'**
  String get progressSigningPdf;

  /// No description provided for @progressParsingPdf.
  ///
  /// In en, this message translates to:
  /// **'Parsing PDF document...'**
  String get progressParsingPdf;

  /// No description provided for @progressDecodingImage.
  ///
  /// In en, this message translates to:
  /// **'Decoding image...'**
  String get progressDecodingImage;

  /// No description provided for @progressResizingImage.
  ///
  /// In en, this message translates to:
  /// **'Resizing image...'**
  String get progressResizingImage;

  /// No description provided for @progressApplyingCloaking.
  ///
  /// In en, this message translates to:
  /// **'Applying adversarial AI cloaking...'**
  String get progressApplyingCloaking;

  /// No description provided for @progressApplyingWatermark.
  ///
  /// In en, this message translates to:
  /// **'Applying watermark...'**
  String get progressApplyingWatermark;

  /// No description provided for @progressEmbeddingRobust.
  ///
  /// In en, this message translates to:
  /// **'Embedding robust watermark (DCT)...'**
  String get progressEmbeddingRobust;

  /// No description provided for @progressHidingFile.
  ///
  /// In en, this message translates to:
  /// **'Hiding file in image (steganography)...'**
  String get progressHidingFile;

  /// No description provided for @progressEmbeddingLsb.
  ///
  /// In en, this message translates to:
  /// **'Embedding invisible signature (LSB)...'**
  String get progressEmbeddingLsb;

  /// No description provided for @progressEncodingImage.
  ///
  /// In en, this message translates to:
  /// **'Encoding image...'**
  String get progressEncodingImage;

  /// No description provided for @progressGeneratingQr.
  ///
  /// In en, this message translates to:
  /// **'Generating QR code...'**
  String get progressGeneratingQr;

  /// No description provided for @progressEmbeddingQr.
  ///
  /// In en, this message translates to:
  /// **'Embedding QR code...'**
  String get progressEmbeddingQr;

  /// No description provided for @progressQrEmbedded.
  ///
  /// In en, this message translates to:
  /// **'QR code embedded'**
  String get progressQrEmbedded;

  /// No description provided for @progressWatermarkingPage.
  ///
  /// In en, this message translates to:
  /// **'Watermarking page {current}/{total}...'**
  String progressWatermarkingPage(int current, int total);

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeAmoled.
  ///
  /// In en, this message translates to:
  /// **'Amoled Black'**
  String get themeAmoled;

  /// No description provided for @resetProfiles.
  ///
  /// In en, this message translates to:
  /// **'Reset Profiles'**
  String get resetProfiles;

  /// No description provided for @resetProfileConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset {profile} to factory defaults?'**
  String resetProfileConfirm(String profile);

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Current configuration saved as default for {profile}'**
  String profileSaved(String profile);

  /// No description provided for @profileReset.
  ///
  /// In en, this message translates to:
  /// **'Profile {profile} reset to factory defaults'**
  String profileReset(String profile);

  /// No description provided for @previewModeOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get previewModeOriginal;

  /// No description provided for @previewModeProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed'**
  String get previewModeProcessed;

  /// No description provided for @previewModeHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Tamper Heatmap'**
  String get previewModeHeatmap;

  /// No description provided for @authenticityVerified.
  ///
  /// In en, this message translates to:
  /// **'AUTHENTICITY VERIFIED'**
  String get authenticityVerified;

  /// No description provided for @fullAuthenticityConfirmed.
  ///
  /// In en, this message translates to:
  /// **'FULL AUTHENTICITY CONFIRMED'**
  String get fullAuthenticityConfirmed;

  /// No description provided for @partialAuthenticity.
  ///
  /// In en, this message translates to:
  /// **'PARTIAL AUTHENTICITY'**
  String get partialAuthenticity;

  /// No description provided for @tamperingDetected.
  ///
  /// In en, this message translates to:
  /// **'TAMPERING DETECTED'**
  String get tamperingDetected;

  /// No description provided for @forensicLayerContent.
  ///
  /// In en, this message translates to:
  /// **'Content (Image + Hidden Data)'**
  String get forensicLayerContent;

  /// No description provided for @forensicLayerSource.
  ///
  /// In en, this message translates to:
  /// **'Source (Visible Image)'**
  String get forensicLayerSource;

  /// No description provided for @forensicStatusValid.
  ///
  /// In en, this message translates to:
  /// **'VALID'**
  String get forensicStatusValid;

  /// No description provided for @forensicStatusModified.
  ///
  /// In en, this message translates to:
  /// **'MODIFIED'**
  String get forensicStatusModified;

  /// No description provided for @verifFullIntegrity.
  ///
  /// In en, this message translates to:
  /// **'Full integrity confirmed (Image + Hidden Data).'**
  String get verifFullIntegrity;

  /// No description provided for @verifPartialIntegrity.
  ///
  /// In en, this message translates to:
  /// **'Visual integrity confirmed, but hidden steganography has been modified or corrupted.'**
  String get verifPartialIntegrity;

  /// No description provided for @verifTamperingDetected.
  ///
  /// In en, this message translates to:
  /// **'Forensic check failed. Both visual pixels and hidden data appear modified.'**
  String get verifTamperingDetected;

  /// No description provided for @onboardingPage1Title.
  ///
  /// In en, this message translates to:
  /// **'Protect your documents'**
  String get onboardingPage1Title;

  /// No description provided for @onboardingPage1Body.
  ///
  /// In en, this message translates to:
  /// **'Visible and invisible watermarks for safe sharing.'**
  String get onboardingPage1Body;

  /// No description provided for @onboardingPage2Title.
  ///
  /// In en, this message translates to:
  /// **'Steganography'**
  String get onboardingPage2Title;

  /// No description provided for @onboardingPage2Body.
  ///
  /// In en, this message translates to:
  /// **'Embed hidden signatures or entire files inside images.'**
  String get onboardingPage2Body;

  /// No description provided for @onboardingPage3Title.
  ///
  /// In en, this message translates to:
  /// **'AI Protection'**
  String get onboardingPage3Title;

  /// No description provided for @onboardingPage3Body.
  ///
  /// In en, this message translates to:
  /// **'Anti-AI protection and Cloaking to disrupt AI models.'**
  String get onboardingPage3Body;

  /// No description provided for @onboardingStepTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get onboardingStepTitle;

  /// No description provided for @onboardingStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Choose a Profile preset for your use case.'**
  String get onboardingStep1;

  /// No description provided for @onboardingStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Import your Images or PDF files.'**
  String get onboardingStep2;

  /// No description provided for @onboardingStep2NoCamera.
  ///
  /// In en, this message translates to:
  /// **'2. Pick your Images or PDF files.'**
  String get onboardingStep2NoCamera;

  /// No description provided for @onboardingStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Click Apply to generate the watermarks.'**
  String get onboardingStep3;

  /// No description provided for @onboardingStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Share or Save the results.'**
  String get onboardingStep4;

  /// No description provided for @onboardingExpertTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles & Options'**
  String get onboardingExpertTitle;

  /// No description provided for @onboardingExpertModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Expert Mode'**
  String get onboardingExpertModeTitle;

  /// No description provided for @onboardingSaveProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Presets'**
  String get onboardingSaveProfileTitle;

  /// No description provided for @onboardingLiveStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Status'**
  String get onboardingLiveStatusTitle;

  /// No description provided for @onboardingFileAnalyzerTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get onboardingFileAnalyzerTitle;

  /// No description provided for @onboardingProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Long-press any profile to save your current configuration as the default for that preset.'**
  String get onboardingProfileSave;

  /// No description provided for @onboardingExpertNote.
  ///
  /// In en, this message translates to:
  /// **'Expert mode (top right) unlocks advanced settings'**
  String get onboardingExpertNote;

  /// No description provided for @onboardingOptionsNote.
  ///
  /// In en, this message translates to:
  /// **'See which options are active (double-tap to open the configuration)'**
  String get onboardingOptionsNote;

  /// No description provided for @onboardingFileAnalyzerNote.
  ///
  /// In en, this message translates to:
  /// **'File Analyzer to check for hidden SecureMark signature or files'**
  String get onboardingFileAnalyzerNote;

  /// No description provided for @onboardingQrCodeNote.
  ///
  /// In en, this message translates to:
  /// **'Embed contact info, links, or metadata via QR code.'**
  String get onboardingQrCodeNote;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get onboardingDone;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @showGuide.
  ///
  /// In en, this message translates to:
  /// **'Show Guide'**
  String get showGuide;
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
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

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
    case 'es':
      return AppLocalizationsEs();
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
