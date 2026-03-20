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
    return 'Processing 1/$count files...';
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
  String previewReadyMobile(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 file',
    );
    return 'Preview ready for $_temp0. You can share them.';
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
  String get close => 'Close';

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
