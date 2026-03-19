// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Application de filigrane';

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
      'Fichiers sélectionnés. Cliquez sur Appliquer le filigrane pour générer les aperçus';

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
  String get pickFiles => 'Choisir des images ou PDF';

  @override
  String selectedFile(String name) {
    return 'Fichier sélectionné : $name';
  }

  @override
  String selectedFiles(int count) {
    return 'Fichiers sélectionnés : $count';
  }

  @override
  String get applyWatermark => 'Appliquer le filigrane';

  @override
  String get saveAll => 'Tout enregistrer';

  @override
  String get shareAll => 'Tout partager';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get watermarkTextLabel => 'Texte du filigrane';

  @override
  String get watermarkTextHint =>
      'Saisissez le texte à estampiller avec la date et l\'heure';

  @override
  String get randomColor => 'Couleur aléatoire';

  @override
  String get selectedColor => 'Couleur choisie';

  @override
  String transparencyValue(int value) {
    return 'Transparence : $value%';
  }

  @override
  String densityValue(int value) {
    return 'Densité : $value%';
  }

  @override
  String get droppedPathUnavailable =>
      'Les chemins des fichiers déposés sont indisponibles.';

  @override
  String get desktopDropArea => 'Zone de dépôt bureau';

  @override
  String get pickerLabel => 'Images et PDF';

  @override
  String selectedApplySingle(String name) {
    return '$name sélectionné. Cliquez sur Appliquer le filigrane.';
  }

  @override
  String selectedApplyMultiple(int count) {
    return '$count fichiers sélectionnés. Cliquez sur Appliquer le filigrane.';
  }

  @override
  String processingCount(int count) {
    return 'Traitement de 0/$count fichiers...';
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
  String get shareText => 'Partage depuis Watermark App';

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
      'Les fichiers seront sauvés dans le même dossier que les originaux avec le préfixe \'watermarked-\'';
}
