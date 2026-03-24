// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'SecureMark';

  @override
  String get emptyPreviewHint =>
      'Geben Sie den Wasserzeichen-Text ein und wählen Sie eine oder mehrere Bild- oder PDF-Dateien aus';

  @override
  String get selectedPreviewHint =>
      'Dateien ausgewählt. Klicken Sie auf SecureMark anwenden, um Vorschauen zu generieren';

  @override
  String selectedFilesLabel(int count) {
    return 'Ausgewählte Dateien ($count)';
  }

  @override
  String get clickApplyToPreview =>
      'Klicken Sie auf \"SecureMark anwenden\", um Vorschauen zu generieren';

  @override
  String get previewUnavailable => 'Vorschau nicht verfügbar';

  @override
  String swipeHint(int current, int total) {
    return 'Nach links für nächste, nach rechts für vorherige wischen ($current/$total)';
  }

  @override
  String get processingFile => 'Datei wird verarbeitet...';

  @override
  String get applyingWatermark => 'Wasserzeichen wird angewendet...';

  @override
  String get processingValidating => 'Datei wird validiert...';

  @override
  String get processingProcessing => 'Datei wird verarbeitet...';

  @override
  String get processingCached => 'Aus dem Cache abgerufen';

  @override
  String get processingComplete => 'Verarbeitung abgeschlossen';

  @override
  String get processingFlattening => 'PDF wird gerastert (flattening)...';

  @override
  String get authorFooter => 'Autor: Antoine Giniès';

  @override
  String get pickFiles => 'Bilder oder PDF';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get takePhotoSubtitle => 'Direkte Verwendung';

  @override
  String selectedFile(String name) {
    return 'Ausgewählte Datei: $name';
  }

  @override
  String selectedFiles(int count) {
    return 'Ausgewählte Dateien: $count';
  }

  @override
  String get applyWatermark => 'SecureMark anwenden';

  @override
  String get saveAll => 'Alle speichern';

  @override
  String get shareAll => 'Alle teilen';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get watermarkTypeText => 'Text';

  @override
  String get watermarkTypeImage => 'Bild/Logo';

  @override
  String get selectWatermarkImage => 'Logo auswählen';

  @override
  String selectedWatermarkImage(String name) {
    return '$name';
  }

  @override
  String get watermarkTextLabel => 'Text zum Stempeln (+Datum-Uhrzeit)';

  @override
  String get watermarkTextHint => 'Geben Sie den Text zum Stempeln ein';

  @override
  String get randomColor => 'Zufällige Farbe';

  @override
  String get selectedColor => 'Ausgewählte Farbe';

  @override
  String transparencyValue(int value) {
    return 'Wasserzeichen-Transparenz: $value%';
  }

  @override
  String densityValue(int value) {
    return 'Dichte: $value%';
  }

  @override
  String get droppedPathUnavailable =>
      'Die Pfade der abgelegten Dateien sind nicht verfügbar.';

  @override
  String get desktopDropArea => 'Dateien hier ablegen';

  @override
  String get pickerLabel => 'Bilder und PDFs';

  @override
  String processingCount(int count) {
    return 'Verarbeite 1/$count Dateien...';
  }

  @override
  String processingNamedFile(int current, int total, String name) {
    return 'Verarbeite $current/$total: $name';
  }

  @override
  String get processingFailed =>
      'Nicht unterstützte Datei oder Verarbeitung fehlgeschlagen.';

  @override
  String errorPrefix(String error) {
    return 'Fehler: $error';
  }

  @override
  String savedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien gespeichert',
      one: '1 Datei gespeichert',
    );
    return '$_temp0.';
  }

  @override
  String get shareSubject => 'Wasserzeichen-Dateien';

  @override
  String get shareText => 'Geteilt von SecureMark';

  @override
  String sharedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien geteilt',
      one: '1 Datei geteilt',
    );
    return '$_temp0.';
  }

  @override
  String shareOpenedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return 'Teilen-Dialog geöffnet für $_temp0.';
  }

  @override
  String get cancel => 'Abbrechen';

  @override
  String get saveLocationInfo =>
      'Dateien werden im selben Ordner wie die Originale mit dem Präfix \'securemark-\' gespeichert';

  @override
  String get expertOptions => 'Experten-Optionen';

  @override
  String fontSizeValue(int value) {
    return 'Schriftgröße: ${value}px';
  }

  @override
  String logoSizeLabel(int value) {
    return 'Logo-Größe: ${value}px';
  }

  @override
  String jpegQualityValue(int value) {
    return 'JPEG-Qualität: $value%';
  }

  @override
  String imageResizingLabel(String size) {
    return 'Bildgrößenänderung: $size';
  }

  @override
  String get imageResizingEnabledHint => 'Bildgrößenänderung ist aktiviert';

  @override
  String get resizeNone => 'Keine (Original)';

  @override
  String pixelUnit(int value) {
    return '$value px';
  }

  @override
  String get includeTimestampFilename =>
      'Datum & Uhrzeit in den Dateinamen aufnehmen';

  @override
  String get preserveExifData => 'Datei-Metadaten beibehalten (EXIF/PDF Info)';

  @override
  String get preserveMetadataEnabledHint =>
      'Datei-Metadaten werden beibehalten';

  @override
  String get rasterizePdfTitle => 'PDF rastern (Flatten)';

  @override
  String get rasterizePdfSubtitle =>
      'Konvertieren Sie PDF-Seiten in Bilder für maximale Sicherheit (größere Datei und langsamer)';

  @override
  String get rasterizePdfEnabledHint => 'PDF wird gerastert (flattening)';

  @override
  String get steganographyTitle => 'Steganographie (Unsichtbare Signatur)';

  @override
  String get steganographySubtitle => 'Text heimlich in Pixeln einbetten.';

  @override
  String get robustSteganographyTitle => 'Robustes Wasserzeichen (DCT-Domäne)';

  @override
  String get robustSteganographySubtitle =>
      'Experimentell: Übersteht Re-Kompression und Größenänderung besser als LSB.';

  @override
  String get filePrefixLabel => 'Datei-Präfix';

  @override
  String get filePrefixHint => 'z.B. wasserzeichen-';

  @override
  String get resetExpertHint =>
      'Dies setzt alle Experten-Einstellungen und das Datei-Präfix auf die Standardwerte zurück.';

  @override
  String get fontStyleLabel => 'Schriftstil';

  @override
  String get fontSelectionNote =>
      'Hinweis: Verwendung optimierter Bitmap-Schriften für schnelles plattformübergreifendes Rendering.';

  @override
  String get fontSelectionNoteGoogle =>
      'Hinweis: Verwendung von Google Fonts für verbesserte Typografie. Erfordert Internetverbindung bei der ersten Verwendung.';

  @override
  String get fontSelectionNoteAsset =>
      'Hinweis: Verwendung einer benutzerdefinierten TTF-Schrift für verbesserte Typografie. Erfordert Schriftdateien in assets/fonts/.';

  @override
  String get resetToDefaults => 'Auf Standardwerte zurücksetzen';

  @override
  String outputDirectoryLabel(String path) {
    return 'Ausgabeverzeichnis: $path';
  }

  @override
  String get selectOutputDirectory => 'Ausgabeverzeichnis wählen';

  @override
  String logoDirectoryLabel(String path) {
    return 'Logo-Verzeichnis: $path';
  }

  @override
  String get selectLogoDirectory => 'Logo-Verzeichnis wählen';

  @override
  String get viewLogs => 'Protokolle anzeigen';

  @override
  String get saveLogs => 'Protokolle speichern';

  @override
  String logsSaved(String path) {
    return 'Protokolle gespeichert unter: $path';
  }

  @override
  String get appLogs => 'App-Protokolle';

  @override
  String get noLogsYet => 'Noch keine Protokolle';

  @override
  String get openGitHub => 'GitHub-Repository öffnen';

  @override
  String get close => 'Schließen';

  @override
  String get aboutApp => 'Über SecureMark';

  @override
  String get appDescription =>
      'Eine professionelle Anwendung zur Sicherung von Dokumenten mit Wasserzeichen für den sicheren Austausch.';

  @override
  String authorLabel(String name) {
    return 'Autor: $name';
  }

  @override
  String get checkForUpdates => 'Nach Updates suchen';

  @override
  String get checkingForUpdates => 'Suche nach Updates...';

  @override
  String get upToDate => 'Sie verwenden die neueste Version.';

  @override
  String updateAvailable(String version) {
    return 'Eine neue Version ($version) ist verfügbar!';
  }

  @override
  String get updateCheckError => 'Suche nach Updates fehlgeschlagen.';

  @override
  String get githubRepository => 'GitHub-Repository';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get viewUpdate => 'Ansehen';

  @override
  String get analyzeFile => 'Datei analysieren (LSB)';

  @override
  String get fileAnalyzerTitle => 'Datei-Analysator (LSB)';

  @override
  String get fileAnalyzerDescription =>
      'Wählen Sie eine Datei aus, um nach versteckten SecureMark-Signaturen zu suchen.';

  @override
  String get pickAndAnalyze => 'Auswählen und analysieren';

  @override
  String encryptedFileDetected(Object name) {
    return '🔐 Verschlüsselte Datei erkannt: $name. Bitte geben Sie das korrekte Passwort ein.';
  }

  @override
  String hiddenFileDetected(Object name, Object size) {
    return '📁 Versteckte Datei erkannt: $name ($size)';
  }

  @override
  String get encryptedSignatureDetected =>
      '🔐 Verschlüsselte Signatur erkannt. Bitte geben Sie das korrekte Passwort ein.';

  @override
  String signatureFound(String message) {
    return '✅ Signatur gefunden: \"$message\"';
  }

  @override
  String robustSignatureFound(String message) {
    return '💪 Robuste Signatur gefunden: \"$message\"';
  }

  @override
  String get noSignatureFound =>
      '❌ Keine SecureMark-Signatur in dieser Datei erkannt.';

  @override
  String analysisError(String error) {
    return 'Fehler bei der Analyse: $error';
  }

  @override
  String get analysisResult => 'Ergebnis:';

  @override
  String get steganographyVerified => 'Steganographie verifiziert';

  @override
  String get steganographyVerificationFailed =>
      'Steganographie-Verifizierung fehlgeschlagen';

  @override
  String get steganographyEnabledHint =>
      'Steganographie ist aktiviert und wird angewendet';

  @override
  String get hideFileWithSteganographyTitle =>
      'Eine Datei verstecken (experimentell)';

  @override
  String get hideFileWithSteganographySubtitle =>
      'Eine ganze Datei in das Bild einbetten (kann die Ausgabegröße erhöhen)';

  @override
  String get hideFileEnabledHint => 'Eine versteckte Datei wird eingebettet';

  @override
  String get selectFileToHide => 'Zu versteckende Datei auswählen';

  @override
  String selectedHiddenFile(String name) {
    return 'Versteckte Datei: $name';
  }

  @override
  String get hiddenFileSecurityWarning =>
      'Sicherheitshinweis: Versteckte Dateien sind nur sicher, wenn sie vor dem Einbetten verschlüsselt wurden. Steganographie verschleiert, verschlüsselt aber nicht Ihre Daten.';

  @override
  String get steganographyPasswordLabel => 'Verschlüsselungspasswort';

  @override
  String get steganographyPasswordHint =>
      'Passwort zum Schutz der versteckten Datei eingeben';

  @override
  String get steganographyPasswordNote =>
      'Hinweis: Dieses Passwort wird benötigt, um die versteckte Datei mit SecureMark zu extrahieren. Es verwendet AES-256-Verschlüsselung.';

  @override
  String get steganographyZipNote =>
      'Wichtig: Wenn Sie Steganographie verwenden und diese Dateien über WhatsApp, Signal oder andere Apps, die Bilder komprimieren, teilen, müssen Sie die ZIP-Komprimierung aktivieren oder sie manuell zippen. Direktes Teilen zerstört normalerweise die unsichtbare Steganographie.';

  @override
  String get zipAllFiles => 'Alle Dateien zippen';

  @override
  String get zipEnabledHint => 'ZIP-Komprimierung für den Austausch aktiviert';

  @override
  String get zipDisabledHint => 'ZIP-Komprimierung deaktiviert';

  @override
  String get qrWatermarkTitle => 'QR-Code-Wasserzeichen';

  @override
  String get enableQrWatermark => 'QR-Code aktivieren';

  @override
  String get enableQrWatermarkSubtitle =>
      'Metadaten in einen QR-Code einbetten';

  @override
  String get qrMode => 'QR-Code-Modus';

  @override
  String get qrVisibleMode => 'Sichtbarer QR-Code';

  @override
  String get qrVisibleModeDesc => 'QR-Code auf dem Bild anzeigen';

  @override
  String get qrAuthorLabel => 'Autor-Name';

  @override
  String get qrAuthorHint => 'z.B. Max Mustermann';

  @override
  String get qrUrlLabel => 'URL oder Webseite';

  @override
  String get qrUrlHint => 'z.B. https://example.com';

  @override
  String get qrVisibleOptions => 'Optionen für sichtbaren QR';

  @override
  String get qrPositionLabel => 'QR-Code-Position';

  @override
  String get qrPosTopLeft => 'Oben links';

  @override
  String get qrPosTopRight => 'Oben rechts';

  @override
  String get qrPosBottomLeft => 'Unten links';

  @override
  String get qrPosBottomRight => 'Unten rechts';

  @override
  String get qrPosCenter => 'Mitte';

  @override
  String qrSizeValue(int value) {
    return 'QR-Code-Größe: ${value}px';
  }

  @override
  String qrOpacityValue(int value) {
    return 'QR-Code-Deckkraft: $value%';
  }

  @override
  String receivedFilesFromSharing(int count) {
    return '📥 $count Datei(en) über Teilen erhalten';
  }

  @override
  String get unsupportedSharedFormat =>
      '⚠️ Geteilte Dateien haben kein unterstütztes Format (JPG, PNG, WebP, PDF, HEIC/HEIF)';

  @override
  String get signatureCopied => 'Signatur in die Zwischenablage kopiert';

  @override
  String get copySignature => 'Signatur kopieren';

  @override
  String get saveHiddenFile => 'Versteckte Datei speichern';

  @override
  String fileSaved(String name) {
    return 'Datei gespeichert: $name';
  }

  @override
  String errorSavingFile(String error) {
    return 'Fehler beim Speichern der Datei: $error';
  }

  @override
  String antiAiProtectionValue(int value) {
    return 'Anti-IA-Schutz: $value%';
  }

  @override
  String get antiAiProtectionNote =>
      'Hinweis: Ein höherer Schutz erhöht die Zeit zur Generierung des SecureMark-Bildes erheblich.';

  @override
  String get antiAiEnabledHint => 'Anti-IA-Schutz ist aktiviert';

  @override
  String get aiCloakingTitle => 'KI-Cloaking (Adversarial)';

  @override
  String get aiCloakingSubtitle =>
      'Injiziert unsichtbares Rauschen, um KI-Training und Style-Diebstahl zu stören.';

  @override
  String get aiCloakingEnabledHint => 'KI-Cloaking ist aktiv';

  @override
  String get qrContentType => 'QR-Inhaltstyp';

  @override
  String get qrTypeMetadata => 'Metadaten (JSON)';

  @override
  String get qrTypeUrl => 'Webseiten-Weiterleitung';

  @override
  String get qrTypeVCard => 'Kontakt (vCard)';

  @override
  String get vCardFirstName => 'Vorname';

  @override
  String get vCardLastName => 'Nachname';

  @override
  String get vCardPhone => 'Telefonnummer';

  @override
  String get vCardEmail => 'E-Mail-Adresse';

  @override
  String get vCardOrg => 'Organisation';

  @override
  String get invalidUrlError =>
      'Bitte geben Sie eine gültige URL ein (z.B. https://example.com)';

  @override
  String get noQrFound => '❌ Kein QR-Code erkannt';

  @override
  String get abToggleTooltipOriginal => 'Original anzeigen';

  @override
  String get abToggleTooltipProcessed => 'Verarbeitet anzeigen';

  @override
  String get processingCancelled => 'Verarbeitung abgebrochen';

  @override
  String processingStatusMultiple(int successCount, int failedCount) {
    return '$successCount Dateien erfolgreich verarbeitet. $failedCount Dateien fehlgeschlagen.';
  }

  @override
  String get processingFailedSingle =>
      'Datei konnte nicht verarbeitet werden. Bitte überprüfen Sie das Dateiformat und versuchen Sie es erneut.';

  @override
  String processingFailedMultiple(int count) {
    return '$count Dateien konnten nicht verarbeitet werden. Bitte überprüfen Sie die Dateiformate und versuchen Sie es erneut.';
  }

  @override
  String fileSavedTo(String path) {
    return 'Datei gespeichert unter: $path';
  }

  @override
  String get saveFailedGeneral =>
      'Dateien konnten nicht gespeichert werden. Bitte überprüfen Sie die Berechtigungen und den Speicherplatz.';

  @override
  String saveStatusMultiple(int successCount, int failedCount) {
    return '$successCount Dateien gespeichert. $failedCount Dateien fehlgeschlagen.';
  }

  @override
  String get filesSavedTitle => 'Dateien gespeichert';

  @override
  String successfullySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien erfolgreich gespeichert',
      one: '1 Datei erfolgreich gespeichert',
    );
    return '$_temp0:';
  }

  @override
  String failedSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien konnten nicht gespeichert werden',
      one: '1 Datei konnte nicht gespeichert werden',
    );
    return '$_temp0:';
  }

  @override
  String willSaveAsIn(String name, String path) {
    return 'Wird gespeichert als: $name in $path/';
  }

  @override
  String willSaveMultipleIn(int count, String path) {
    return 'Wird $count Dateien speichern in: $path/';
  }

  @override
  String get savingFiles => 'Dateien werden gespeichert...';

  @override
  String errorSavingFiles(String error) {
    return 'Fehler beim Speichern der Dateien: $error';
  }

  @override
  String get foregroundTaskTitle => 'SecureMark Verarbeitung';

  @override
  String get foregroundTaskDescription =>
      'Fortschritt der Dokumenten-Wasserzeichen-Anwendung anzeigen';

  @override
  String foregroundTaskUpdate(int current, int total, String name) {
    return 'Verarbeite Datei $current von $total: $name';
  }

  @override
  String get fileTooLargeTitle => 'Datei zu groß';

  @override
  String fileTooLargeMessage(String fileName, String fileSize,
      String imageDimensions, String maxCapacity) {
    return 'Die Datei \"$fileName\" ($fileSize KB) ist zu groß, um in diesem Bild ($imageDimensions) versteckt zu werden.\n\nMaximale Kapazität: $maxCapacity KB\n\nBitte verwenden Sie ein größeres Bild oder komprimieren/reduzieren Sie die Dateigröße.';
  }

  @override
  String get loadingSelectedFiles => 'Ausgewählte Dateien werden geladen...';

  @override
  String get profileLabel => 'Profil';

  @override
  String get profileDescription =>
      'Schnelle Voreinstellungen für häufige Anwendungsfälle';

  @override
  String get profileNone => 'Custom';

  @override
  String get profileSecureIdentity => 'Identität';

  @override
  String get profileOnlineImage => 'Bild';

  @override
  String get profileQrCode => 'QR-Code';

  @override
  String get profileShareDocument => 'Dokument';

  @override
  String get progressValidating => 'Datei wird validiert...';

  @override
  String get progressFromCache => 'Aus dem Cache abgerufen';

  @override
  String get progressDetectingType => 'Dateityp wird erkannt...';

  @override
  String get progressStarting => 'Verarbeitung wird gestartet...';

  @override
  String get progressComplete => 'Verarbeitung abgeschlossen';

  @override
  String get progressReadingImage => 'Bilddatei wird gelesen...';

  @override
  String get progressRenderingFont => 'Schriftart wird gerendert...';

  @override
  String get progressFinalizingImage => 'Bild wird finalisiert...';

  @override
  String get progressVerifyingStegano => 'Steganographie wird überprüft...';

  @override
  String get progressSteganoVerified => 'Steganographie verifiziert';

  @override
  String get progressSteganoFailed =>
      'Steganographie-Überprüfung fehlgeschlagen';

  @override
  String get progressRasterizing => 'PDF wird gerastert (flattening)...';

  @override
  String get progressReadingPdf => 'PDF-Datei wird gelesen...';

  @override
  String get progressAddingLayer => 'Wasserzeichen-Ebene wird hinzugefügt...';

  @override
  String get progressFinalizingPdf => 'PDF wird finalisiert...';

  @override
  String get progressParsingPdf => 'PDF-Dokument wird analysiert...';

  @override
  String get progressDecodingImage => 'Bild wird dekodiert...';

  @override
  String get progressResizingImage => 'Bildgröße wird angepasst...';

  @override
  String get progressApplyingCloaking =>
      'Adversarielles KI-Cloaking wird angewendet...';

  @override
  String get progressApplyingWatermark => 'Wasserzeichen wird angewendet...';

  @override
  String get progressEmbeddingRobust =>
      'Robustes Wasserzeichen wird eingebettet (DCT)...';

  @override
  String get progressHidingFile =>
      'Datei wird im Bild versteckt (Steganographie)...';

  @override
  String get progressEmbeddingLsb =>
      'Unsichtbare Signatur wird eingebettet (LSB)...';

  @override
  String get progressEncodingImage => 'Bild wird kodiert...';

  @override
  String get progressGeneratingQr => 'QR-Code wird generiert...';

  @override
  String get progressEmbeddingQr => 'QR-Code wird eingebettet...';

  @override
  String get progressQrEmbedded => 'QR-Code eingebettet';

  @override
  String progressWatermarkingPage(int current, int total) {
    return 'Seite $current/$total wird markiert...';
  }

  @override
  String get themeLabel => 'Design';

  @override
  String get themeSystem => 'Systemstandard';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

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
