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
  String get emptyPreviewHint =>
      'Saisissez le texte du filigrane puis choisissez une ou plusieurs images ou PDF';

  @override
  String get selectedPreviewHint =>
      'Fichiers sélectionnés. Cliquez sur Appliquer SecureMark pour générer les aperçus';

  @override
  String selectedFilesLabel(int count) {
    return 'Fichiers sélectionnés ($count)';
  }

  @override
  String get clickApplyToPreview =>
      'Cliquez sur \"Appliquer SecureMark\" pour générer les aperçus';

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
  String get processingValidating => 'Validation du fichier...';

  @override
  String get processingProcessing => 'Traitement du fichier...';

  @override
  String get processingCached => 'Récupéré du cache';

  @override
  String get processingComplete => 'Traitement terminé';

  @override
  String get processingFlattening => 'Rasterisation du PDF (aplatissement)...';

  @override
  String get authorFooter => 'Auteur : Antoine Giniès';

  @override
  String get pickFiles => 'Images ou PDF';

  @override
  String get takePhoto => 'Prendre une Photo';

  @override
  String get takePhotoSubtitle => 'Utilisation directe';

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
  String get watermarkTypeText => 'Texte';

  @override
  String get watermarkTypeImage => 'Image/Logo';

  @override
  String get selectWatermarkImage => 'Choisir un Logo';

  @override
  String selectedWatermarkImage(String name) {
    return '$name';
  }

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
  String logoSizeLabel(int value) {
    return 'Taille du Logo : ${value}px';
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
  String get imageResizingEnabledHint =>
      'Le redimensionnement d\'image est activé';

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
  String get preserveMetadataEnabledHint =>
      'Les métadonnées du fichier seront préservées';

  @override
  String get rasterizePdfTitle => 'Rasteriser le PDF (Aplatir)';

  @override
  String get rasterizePdfSubtitle =>
      'Convertir les pages PDF en images pour une sécurité maximale (plus lourd et plus lent)';

  @override
  String get rasterizePdfEnabledHint => 'Le PDF sera rasterisé (aplatir)';

  @override
  String get steganographyTitle => 'Stéganographie (Signature Invisible)';

  @override
  String get steganographySubtitle =>
      'Masquer secrètement du texte dans les pixels.';

  @override
  String get robustSteganographyTitle => 'Filigrane Robuste (Domaine DCT)';

  @override
  String get robustSteganographySubtitle =>
      'Expérimental : Survit mieux à la re-compression et au redimensionnement que le LSB.';

  @override
  String get filePrefixLabel => 'Préfixe de fichier';

  @override
  String get filePrefixHint => 'ex: filigrane-';

  @override
  String get resetExpertHint =>
      'Cela réinitialisera tous les réglages experts et le préfixe de fichier aux valeurs par défaut.';

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
  String get resetToDefaults => 'Réinitialiser par défaut';

  @override
  String outputDirectoryLabel(String path) {
    return 'Dossier de sortie : $path';
  }

  @override
  String get selectOutputDirectory => 'Choisir le dossier de sortie';

  @override
  String logoDirectoryLabel(String path) {
    return 'Dossier des logos : $path';
  }

  @override
  String get selectLogoDirectory => 'Choisir le dossier des logos';

  @override
  String get viewLogs => 'Voir les logs';

  @override
  String get saveLogs => 'Enregistrer les logs';

  @override
  String logsSaved(String path) {
    return 'Logs enregistrés dans : $path';
  }

  @override
  String get appLogs => 'Logs de l\'application';

  @override
  String get noLogsYet => 'Aucun log pour le moment';

  @override
  String get openGitHub => 'Voir le dépôt GitHub';

  @override
  String get close => 'Fermer';

  @override
  String get aboutApp => 'À propos de SecureMark';

  @override
  String get appDescription =>
      'Une application professionnelle pour sécuriser vos documents avec des filigranes pour un partage sûr.';

  @override
  String authorLabel(String name) {
    return 'Auteur : $name';
  }

  @override
  String get checkForUpdates => 'Vérifier les mises à jour';

  @override
  String get checkingForUpdates => 'Vérification en cours...';

  @override
  String get upToDate => 'Vous utilisez la dernière version.';

  @override
  String updateAvailable(String version) {
    return 'Une nouvelle version ($version) est disponible !';
  }

  @override
  String get updateCheckError => 'Impossible de vérifier les mises à jour.';

  @override
  String get githubRepository => 'Dépôt GitHub';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get viewUpdate => 'Voir';

  @override
  String get analyzeFile => 'Analyser un fichier (LSB)';

  @override
  String get fileAnalyzerTitle => 'Analyseur de fichiers (LSB)';

  @override
  String get fileAnalyzerDescription =>
      'Sélectionnez un fichier pour rechercher des signatures SecureMark cachées.';

  @override
  String get pickAndAnalyze => 'Choisir et analyser';

  @override
  String encryptedFileDetected(Object name) {
    return '🔐 Fichier chiffré détecté : $name. Veuillez fournir le mot de passe correct.';
  }

  @override
  String hiddenFileDetected(Object name, Object size) {
    return '📁 Fichier caché détecté : $name ($size)';
  }

  @override
  String get encryptedSignatureDetected =>
      '🔐 Signature chiffrée détectée. Veuillez fournir le mot de passe correct.';

  @override
  String signatureFound(String message) {
    return '✅ Signature trouvée : \"$message\"';
  }

  @override
  String robustSignatureFound(String message) {
    return '💪 Signature robuste trouvée : \"$message\"';
  }

  @override
  String get noSignatureFound =>
      '❌ Aucune signature SecureMark détectée dans ce fichier.';

  @override
  String analysisError(String error) {
    return 'Erreur pendant l\'analyse : $error';
  }

  @override
  String get analysisResult => 'Résultat :';

  @override
  String get steganographyVerified => 'Stéganographie Vérifiée';

  @override
  String get steganographyVerificationFailed =>
      'Échec de la vérification de la stéganographie';

  @override
  String get steganographyEnabledHint =>
      'La stéganographie est activée et sera appliquée';

  @override
  String get hideFileWithSteganographyTitle =>
      'Cacher un fichier (expérimental)';

  @override
  String get hideFileWithSteganographySubtitle =>
      'Incorporer un fichier entier dans l\'image (peut augmenter la taille de sortie)';

  @override
  String get hideFileEnabledHint => 'Un fichier caché sera incorporé';

  @override
  String get selectFileToHide => 'Sélectionner un fichier à cacher';

  @override
  String selectedHiddenFile(String name) {
    return 'Fichier caché : $name';
  }

  @override
  String get hiddenFileSecurityWarning =>
      'Avis de sécurité : Les fichiers cachés ne sont sécurisés que s\'ils sont chiffrés avant l\'incorporation. La stéganographie obscurcit mais ne chiffre pas vos données.';

  @override
  String get steganographyPasswordLabel => 'Mot de passe de chiffrage';

  @override
  String get steganographyPasswordHint =>
      'Entrez le mot de passe pour protéger le fichier caché';

  @override
  String get steganographyPasswordNote =>
      'Remarque : Ce mot de passe sera requis pour extraire le fichier caché à l\'aide de SecureMark. Il utilise le chiffrage AES-256.';

  @override
  String get steganographyZipNote =>
      'Important : Si vous utilisez la stéganographie et partagez ces fichiers via WhatsApp, Signal ou d\'autres applications qui compressent les images, vous devez activer la compression ZIP (dans les Options Expert) ou les zipper manuellement. Le partage direct détruit généralement la stéganographie invisible.';

  @override
  String get zipAllFiles => 'Zipper tous les fichiers';

  @override
  String get zipEnabledHint => 'Compression ZIP activée pour le partage';

  @override
  String get zipDisabledHint => 'Compression ZIP désactivée';

  @override
  String get qrWatermarkTitle => 'Filigrane QR Code';

  @override
  String get enableQrWatermark => 'Activer le QR Code';

  @override
  String get enableQrWatermarkSubtitle =>
      'Intégrer des métadonnées dans un QR code';

  @override
  String get qrMode => 'Mode QR Code';

  @override
  String get qrVisibleMode => 'QR Code Visible';

  @override
  String get qrVisibleModeDesc => 'Afficher le QR code sur l\'image';

  @override
  String get qrAuthorLabel => 'Nom de l\'auteur';

  @override
  String get qrAuthorHint => 'ex: Jean Dupont';

  @override
  String get qrUrlLabel => 'URL ou Site Web';

  @override
  String get qrUrlHint => 'ex: https://exemple.fr';

  @override
  String get qrVisibleOptions => 'Options QR Visible';

  @override
  String get qrPositionLabel => 'Position du QR Code';

  @override
  String get qrPosTopLeft => 'Haut Gauche';

  @override
  String get qrPosTopRight => 'Haut Droite';

  @override
  String get qrPosBottomLeft => 'Bas Gauche';

  @override
  String get qrPosBottomRight => 'Bas Droite';

  @override
  String get qrPosCenter => 'Centre';

  @override
  String qrSizeValue(int value) {
    return 'Taille du QR Code : ${value}px';
  }

  @override
  String qrOpacityValue(int value) {
    return 'Opacité du QR Code : $value%';
  }

  @override
  String receivedFilesFromSharing(int count) {
    return '📥 $count fichier(s) reçu(s) depuis le partage';
  }

  @override
  String get unsupportedSharedFormat =>
      '⚠️ Les fichiers partagés ne sont pas dans un format supporté (JPG, PNG, WebP, PDF, HEIC/HEIF)';

  @override
  String get signatureCopied => 'Signature copiée dans le presse-papier';

  @override
  String get copySignature => 'Copier la signature';

  @override
  String get saveHiddenFile => 'Enregistrer le fichier caché';

  @override
  String fileSaved(String name) {
    return 'Fichier enregistré : $name';
  }

  @override
  String errorSavingFile(String error) {
    return 'Erreur lors de l\'enregistrement : $error';
  }

  @override
  String antiAiProtectionValue(int value) {
    return 'Protection Anti-Suppression IA : $value%';
  }

  @override
  String get antiAiProtectionNote =>
      'Note : ajoute des micro-variations et du bruit pour rendre le filigrane beaucoup plus difficile à supprimer par une IA. Les niveaux élevés prennent plus de temps.';

  @override
  String get antiAiEnabledHint =>
      'La protection contre la suppression par IA est activée';

  @override
  String get aiCloakingTitle => 'Cloaking IA (Adversaire)';

  @override
  String get aiCloakingSubtitle =>
      'Injecte un bruit invisible pour perturber l\'entraînement des IA et le vol de style.';

  @override
  String get aiCloakingEnabledHint => 'Le Cloaking IA est actif';

  @override
  String get qrContentType => 'Type de contenu QR';

  @override
  String get qrTypeMetadata => 'Métadonnées (JSON)';

  @override
  String get qrTypeUrl => 'Redirection Site Web';

  @override
  String get qrTypeVCard => 'Contact (vCard)';

  @override
  String get vCardFirstName => 'Prénom';

  @override
  String get vCardLastName => 'Nom';

  @override
  String get vCardPhone => 'Numéro de téléphone';

  @override
  String get vCardEmail => 'Adresse email';

  @override
  String get vCardOrg => 'Organisation';

  @override
  String get invalidUrlError =>
      'Veuillez entrer une URL valide (ex: https://exemple.fr)';

  @override
  String get noQrFound => '❌ Aucun code QR détecté';

  @override
  String get abToggleTooltipOriginal => 'Afficher l\'original';

  @override
  String get abToggleTooltipProcessed => 'Afficher le traité';

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

  @override
  String get fileTooLargeTitle => 'Fichier trop volumineux';

  @override
  String fileTooLargeMessage(String fileName, String fileSize,
      String imageDimensions, String maxCapacity) {
    return 'Le fichier \"$fileName\" ($fileSize Ko) est trop volumineux pour être caché dans cette image ($imageDimensions).\n\nCapacité maximale : $maxCapacity Ko\n\nVeuillez utiliser une image plus grande ou compresser/réduire la taille du fichier.';
  }

  @override
  String get loadingSelectedFiles => 'Chargement des fichiers sélectionnés...';

  @override
  String get profileLabel => 'Profil';

  @override
  String get profileDescription =>
      'Préréglages rapides pour les cas d\'usage courants';

  @override
  String get profileNone => 'Custom';

  @override
  String get profileSecureIdentity => 'Identité';

  @override
  String get profileOnlineImage => 'Image';

  @override
  String get profileQrCode => 'QR Code';

  @override
  String get profileShareDocument => 'Doc';

  @override
  String get progressValidating => 'Validation du fichier...';

  @override
  String get progressFromCache => 'Récupéré du cache';

  @override
  String get progressDetectingType => 'Détection du type de fichier...';

  @override
  String get progressStarting => 'Démarrage du traitement...';

  @override
  String get progressComplete => 'Traitement terminé';

  @override
  String get progressReadingImage => 'Lecture du fichier image...';

  @override
  String get progressRenderingFont => 'Rendu de la police...';

  @override
  String get progressFinalizingImage => 'Finalisation de l\'image...';

  @override
  String get progressVerifyingStegano => 'Vérification de la stéganographie...';

  @override
  String get progressSteganoVerified => 'Stéganographie vérifiée';

  @override
  String get progressSteganoFailed =>
      'Échec de la vérification stéganographique';

  @override
  String get progressRasterizing => 'Rasterisation du PDF (aplatissement)...';

  @override
  String get progressReadingPdf => 'Lecture du fichier PDF...';

  @override
  String get progressAddingLayer => 'Ajout du calque de filigrane...';

  @override
  String get progressFinalizingPdf => 'Finalisation du PDF...';

  @override
  String get progressParsingPdf => 'Analyse du document PDF...';

  @override
  String get progressDecodingImage => 'Décodage de l\'image...';

  @override
  String get progressResizingImage => 'Redimensionnement de l\'image...';

  @override
  String get progressApplyingCloaking => 'Application du cloaking IA...';

  @override
  String get progressApplyingWatermark => 'Application du filigrane...';

  @override
  String get progressEmbeddingRobust =>
      'Incorporation du filigrane robuste (DCT)...';

  @override
  String get progressHidingFile =>
      'Masquage du fichier dans l\'image (stéganographie)...';

  @override
  String get progressEmbeddingLsb =>
      'Incorporation de la signature invisible (LSB)...';

  @override
  String get progressEncodingImage => 'Encodage de l\'image...';

  @override
  String get progressGeneratingQr => 'Génération du code QR...';

  @override
  String get progressEmbeddingQr => 'Incorporation du code QR...';

  @override
  String get progressQrEmbedded => 'Code QR incorporé';

  @override
  String progressWatermarkingPage(int current, int total) {
    return 'Marquage de la page $current/$total...';
  }

  @override
  String get themeLabel => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

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
}
