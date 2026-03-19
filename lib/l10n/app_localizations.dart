import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Watermark App'**
  String get appTitle;

  /// No description provided for @readyToSaveFiles.
  ///
  /// In en, this message translates to:
  /// **'Ready to save {count, plural, one {1 file} other {{count} files}}'**
  String readyToSaveFiles(int count);

  /// No description provided for @emptyPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Enter watermark text and pick one or more image or PDF files'**
  String get emptyPreviewHint;

  /// No description provided for @selectedPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Files selected. Click Apply Watermark to generate previews'**
  String get selectedPreviewHint;

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

  /// No description provided for @authorFooter.
  ///
  /// In en, this message translates to:
  /// **'Author: guibo'**
  String get authorFooter;

  /// No description provided for @pickFiles.
  ///
  /// In en, this message translates to:
  /// **'Pick Image or PDF Files'**
  String get pickFiles;

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
  /// **'Apply Watermark'**
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

  /// No description provided for @watermarkTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Watermark text'**
  String get watermarkTextLabel;

  /// No description provided for @watermarkTextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the text to stamp with date and time'**
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
  /// **'Desktop drop area'**
  String get desktopDropArea;

  /// No description provided for @pickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Images and PDFs'**
  String get pickerLabel;

  /// No description provided for @selectedApplySingle.
  ///
  /// In en, this message translates to:
  /// **'Selected {name}. Click Apply Watermark.'**
  String selectedApplySingle(String name);

  /// No description provided for @selectedApplyMultiple.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} files. Click Apply Watermark.'**
  String selectedApplyMultiple(int count);

  /// No description provided for @processingCount.
  ///
  /// In en, this message translates to:
  /// **'Processing 0/{count} files...'**
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

  /// No description provided for @previewReady.
  ///
  /// In en, this message translates to:
  /// **'Preview ready for {count, plural, one {1 file} other {{count} files}}. You can save or share them.'**
  String previewReady(int count);

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
  /// **'Shared from Watermark App'**
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
  /// **'Files will be saved in the same folder as originals with \'watermarked-\' prefix'**
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

  /// No description provided for @resizeNone.
  ///
  /// In en, this message translates to:
  /// **'None (Original)'**
  String get resizeNone;

  /// No description provided for @includeTimestampFilename.
  ///
  /// In en, this message translates to:
  /// **'Include Date & Hour in Filename'**
  String get includeTimestampFilename;

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

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
