// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'SecureMark';

  @override
  String readyToSaveFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return 'Prêt à enregistrer $_temp0';
  }

  @override
  String get emptyPreviewHint =>
      'Saisissez le texte du filigrane puis choisissez une ou plusieurs images ou PDF';

  @override
  String get selectedPreviewHint =>
      'Fichiers sélectionnés. Cliquez sur Appliquer SecureMark pour générer les aperçus';

  @override
  String get previewUnavailable => 'Aperçu indisponible';

  @override
  String swipeHint(int current, int total) {
    return 'Glissez à gauche pour le suivant, à droite pour le précédent ($current/$total)';
  }

  @override
  String get processingFile => 'Traitement du fichier...';

  @override
  String get applyingWatermark => 'Application du filigrane...';

  @override
  String get authorFooter => 'Auteur : guibo';

  @override
  String get pickFiles => 'Images ou PDF';

  @override
  String selectedFile(String name) {
    return 'Fichier sélectionné : $name';
  }

  @override
  String selectedFiles(int count) {
    return 'Fichiers sélectionnés : $count';
  }

  @override
  String get applyWatermark => 'Appliquer SecureMark';

  @override
  String get saveAll => 'Tout enregistrer';

  @override
  String get shareAll => 'Tout partager';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get watermarkTextLabel => 'Texte à tamponner (+Date-Heure)';

  @override
  String get watermarkTextHint => 'Saisissez le texte à tamponner';

  @override
  String get randomColor => 'Couleur aléatoire';

  @override
  String get selectedColor => 'Couleur choisie';

  @override
  String transparencyValue(int value) {
    return 'Transparence du filigrane : $value%';
  }

  @override
  String densityValue(int value) {
    return 'Densité : $value%';
  }

  @override
  String get droppedPathUnavailable =>
      'Les chemins des fichiers déposés sont indisponibles.';

  @override
  String get desktopDropArea => 'Déposer les fichiers ici';

  @override
  String get pickerLabel => 'Images et PDF';

  @override
  String selectedApplySingle(String name) {
    return '$name sélectionné. Cliquez sur Appliquer SecureMark.';
  }

  @override
  String selectedApplyMultiple(int count) {
    return '$count fichiers sélectionnés. Cliquez sur Appliquer SecureMark.';
  }

  @override
  String processingCount(int count) {
    return 'Traitement de 1/$count fichiers...';
  }

  @override
  String processingNamedFile(int current, int total, String name) {
    return 'Traitement $current/$total : $name';
  }

  @override
  String get processingFailed =>
      'Fichier non pris en charge ou échec du traitement.';

  @override
  String previewReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return 'Aperçu prêt pour $_temp0. Vous pouvez les enregistrer ou les partager.';
  }

  @override
  String previewReadyMobile(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return 'Aperçu prêt pour $_temp0. Vous pouvez les partager.';
  }

  @override
  String errorPrefix(String error) {
    return 'Erreur : $error';
  }

  @override
  String savedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers enregistrés',
      one: '1 fichier enregistré',
    );
    return '$_temp0.';
  }

  @override
  String get shareSubject => 'Fichiers filigranés';

  @override
  String get shareText => 'Partage depuis SecureMark';

  @override
  String sharedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers partagés',
      one: '1 fichier partagé',
    );
    return '$_temp0.';
  }

  @override
  String shareOpenedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return 'La feuille de partage est ouverte pour $_temp0.';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get saveLocationInfo =>
      'Les fichiers seront sauvés dans le même dossier que les originaux avec le préfixe \'securemark-\'';

  @override
  String get expertOptions => 'Options d\'expert';

  @override
  String fontSizeValue(int value) {
    return 'Taille de police : ${value}px';
  }

  @override
  String jpegQualityValue(int value) {
    return 'Qualité JPEG : $value%';
  }

  @override
  String imageResizingLabel(String size) {
    return 'Redimensionnement : $size';
  }

  @override
  String get resizeNone => 'Aucun (Original)';

  @override
  String pixelUnit(int value) {
    return '$value px';
  }

  @override
  String get includeTimestampFilename =>
      'Inclure Date & Heure dans le nom du fichier';

  @override
  String get preserveExifData => 'Préserver les métadonnées (EXIF/Infos PDF)';

  @override
  String get fontStyleLabel => 'Style de police';

  @override
  String get fontSelectionNote =>
      'Note : Utilisation de polices bitmap optimisées pour un rendu rapide multi-plateforme.';

  @override
  String get fontSelectionNoteGoogle =>
      'Note : Utilisation de Google Fonts pour une typographie améliorée. Internet requis pour la première utilisation.';

  @override
  String get fontSelectionNoteAsset =>
      'Note : Utilisation d\'une police TTF personnalisée pour une typographie améliorée. Nécessite des fichiers de police dans assets/fonts/.';

  @override
  String outputDirectoryLabel(String path) {
    return 'Dossier de sortie : $path';
  }

  @override
  String get selectOutputDirectory => 'Choisir le dossier de sortie';

  @override
  String get viewLogs => 'Voir les logs';

  @override
  String get appLogs => 'Logs de l\'application';

  @override
  String get noLogsYet => 'Aucun log pour le moment';

  @override
  String get openGitHub => 'Voir le dépôt GitHub';

  @override
  String get close => 'Fermer';

  @override
  String get processingCancelled => 'Traitement annulé';

  @override
  String processingStatusMultiple(int successCount, int failedCount) {
    return '$successCount fichiers traités avec succès. $failedCount fichiers ont échoué.';
  }

  @override
  String get processingFailedSingle =>
      'Échec du traitement du fichier. Veuillez vérifier le format du fichier et réessayer.';

  @override
  String processingFailedMultiple(int count) {
    return 'Échec du traitement de $count fichiers. Veuillez vérifier les formats de fichiers et réessayer.';
  }

  @override
  String fileSavedTo(String path) {
    return 'Fichier enregistré dans : $path';
  }

  @override
  String get saveFailedGeneral =>
      'Échec de l\'enregistrement des fichiers. Veuillez vérifier les permissions et l\'espace de stockage.';

  @override
  String saveStatusMultiple(int successCount, int failedCount) {
    return '$successCount fichiers enregistrés. $failedCount fichiers ont échoué.';
  }

  @override
  String get filesSavedTitle => 'Fichiers Enregistrés';

  @override
  String successfullySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers enregistrés',
      one: '1 fichier enregistré',
    );
    return '$_temp0 avec succès :';
  }

  @override
  String failedSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return 'Échec de l\'enregistrement de $_temp0 :';
  }

  @override
  String willSaveAsIn(String name, String path) {
    return 'Sera enregistré sous : $name dans $path/';
  }

  @override
  String willSaveMultipleIn(int count, String path) {
    return 'Sera enregistré $count fichiers dans : $path/';
  }

  @override
  String get savingFiles => 'Enregistrement des fichiers...';

  @override
  String errorSavingFiles(String error) {
    return 'Erreur lors de l\'enregistrement des fichiers : $error';
  }

  @override
  String get foregroundTaskTitle => 'Traitement SecureMark';

  @override
  String get foregroundTaskDescription =>
      'Affichage de la progression du filigranage des documents';

  @override
  String foregroundTaskUpdate(int current, int total, String name) {
    return 'Traitement du fichier $current sur $total : $name';
  }
}
