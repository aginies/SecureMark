// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Watermark App';

  @override
  String readyToSaveFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Ready to save $_temp0';
  }

  @override
  String get emptyPreviewHint =>
      'Enter watermark text and pick one or more image or PDF files';

  @override
  String get selectedPreviewHint =>
      'Files selected. Click Apply Watermark to generate previews';

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
  String get authorFooter => 'Author: guibo';

  @override
  String get pickFiles => 'Pick Image or PDF Files';

  @override
  String selectedFile(String name) {
    return 'Selected file: $name';
  }

  @override
  String selectedFiles(int count) {
    return 'Selected files: $count';
  }

  @override
  String get applyWatermark => 'Apply Watermark';

  @override
  String get saveAll => 'Save All';

  @override
  String get shareAll => 'Share All';

  @override
  String get reset => 'Reset';

  @override
  String get watermarkTextLabel => 'Watermark text';

  @override
  String get watermarkTextHint => 'Enter the text to stamp with date and time';

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
  String get desktopDropArea => 'Desktop drop area';

  @override
  String get pickerLabel => 'Images and PDFs';

  @override
  String selectedApplySingle(String name) {
    return 'Selected $name. Click Apply Watermark.';
  }

  @override
  String selectedApplyMultiple(int count) {
    return 'Selected $count files. Click Apply Watermark.';
  }

  @override
  String processingCount(int count) {
    return 'Processing 0/$count files...';
  }

  @override
  String processingNamedFile(int current, int total, String name) {
    return 'Processing $current/$total: $name';
  }

  @override
  String get processingFailed => 'Unsupported file or processing failed.';

  @override
  String previewReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Preview ready for $_temp0. You can save or share them.';
  }

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
  String get shareText => 'Shared from Watermark App';

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
      'Files will be saved in the same folder as originals with \'watermarked-\' prefix';

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
  String get includeTimestampFilename => 'Include Date & Hour in Filename';

  @override
  String get fontStyleLabel => 'Font Style';

  @override
  String get fontSelectionNote =>
      'Note: Using optimized bitmap fonts for fast cross-platform rendering.';

  @override
  String get fontSelectionNoteGoogle =>
      'Note: Using Google Fonts for enhanced typography. Requires internet for first use.';

  @override
  String get close => 'Close';
}
