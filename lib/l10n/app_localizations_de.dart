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
  String get takePhoto => 'Klassisches Foto';

  @override
  String get takePhotoSubtitle => 'Standard-Kameraaufnahme';

  @override
  String get scanDocument => 'Dokument scannen';

  @override
  String get scanDocumentSubtitle => 'Scan mit Kantenerkennung';

  @override
  String get captureMenuTitle => 'Aufnahmemethode';

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
  String get delete => 'Löschen';

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
  String get color => 'Farbe';

  @override
  String transparencyValue(int value) {
    return 'Transparenz: $value%';
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
  String get pdfSecurityTitle => 'Erweiterte PDF-Sicherheit';

  @override
  String get enablePdfSecurity => 'PDF-Sicherheit aktivieren';

  @override
  String get pdfSecuritySubtitle =>
      'PDF mit Passwörtern schützen und Berechtigungen einschränken';

  @override
  String get pdfUserPasswordLabel => 'Benutzerpasswort (zum Öffnen)';

  @override
  String get pdfUserPasswordHint =>
      'Passwort zum Anzeigen des PDFs erforderlich';

  @override
  String get pdfOwnerPasswordLabel => 'Besitzerpasswort (für Einschränkungen)';

  @override
  String get pdfOwnerPasswordHint =>
      'Passwort zum Ändern von Berechtigungen erforderlich';

  @override
  String get pdfAllowPrinting => 'Drucken erlauben';

  @override
  String get pdfAllowCopying => 'Kopieren von Text/Inhalt erlauben';

  @override
  String get pdfAllowEditing => 'Anmerkungen/Bearbeitung erlauben';

  @override
  String get pdfSecurityNote =>
      'Hinweis: Sicherheitseinstellungen gelten nur für PDF-Dateien und hängen von der Unterstützung des Viewers ab.';

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
  String get fontConfigTitle => 'Schriftkonfiguration';

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
  String get analyzeFile => 'Datei analysieren';

  @override
  String get fileAnalyzerTitle => 'Datei-Analysator';

  @override
  String get fileAnalyzerDescription =>
      'Wählen Sie eine Datei aus, um nach versteckten SecureMark-Signaturen zu suchen.';

  @override
  String get pickAndAnalyze => 'Auswählen und analysieren';

  @override
  String encryptedFileDetected(String name) {
    return '🔐 Verschlüsselte Datei erkannt: $name. Bitte geben Sie das korrekte Passwort ein.';
  }

  @override
  String hiddenFileDetected(String name, String size) {
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
  String get missingSteganographySignature =>
      'Die benutzerdefinierte Steganographie-Signatur darf nicht leer sein, wenn die Steganographie aktiviert ist.';

  @override
  String get missingQrContent =>
      'Der Inhalt des QR-Codes darf nicht leer sein, wenn der QR-Code aktiviert ist.';

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
  String get steganographyImageOnlyNote =>
      'Hinweis: Steganographie (unsichtbare Signaturen und versteckte Dateien) wird nur für Bilddateien (JPG, PNG, WebP) unterstützt. Bei PDF-Dateien wird sie übersprungen.';

  @override
  String get steganographyTextLabel =>
      'Benutzerdefinierte steganographische Signatur';

  @override
  String get steganographyTextHint =>
      'Geben Sie den benutzerdefinierten Text ein, der ausgeblendet werden soll (verwendet standardmäßig den Wasserzeichen-Text, falls leer)';

  @override
  String get zipAllFiles => 'Alle Dateien zippen';

  @override
  String get secureZipTitle => 'Sicheres ZIP-Archiv';

  @override
  String get enableSecureZip => 'AES-256-Verschlüsselung aktivieren';

  @override
  String get secureZipPasswordLabel => 'ZIP-Passwort';

  @override
  String get secureZipPasswordHint =>
      'Passwort zum Extrahieren des ZIP-Archivs';

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
    return 'Anti-KI-Schutz: $value%';
  }

  @override
  String get antiAiProtectionNote =>
      'Hinweis: Ein höherer Schutz erhöht die Zeit zur Generierung des SecureMark-Bildes erheblich.';

  @override
  String get antiAiEnabledHint => 'Anti-KI-Schutz ist aktiviert';

  @override
  String get antiAiProtectionTitle => 'Anti-KI-Entfernungsschutz';

  @override
  String get antiAiProtectionSubtitle =>
      'Fügt Rauschen hinzu, um Wasserzeichen schwerer durch KI entfernbar zu machen';

  @override
  String get aiCloakingTitle => 'KI-Cloaking (Adversarial)';

  @override
  String get aiCloakingSubtitle =>
      'Injiziert unsichtbares Rauschen, um KI-Training und Style-Diebstahl zu stören.';

  @override
  String get aiCloakingEnabledHint => 'KI-Cloaking ist aktiv';

  @override
  String get digitallySignTitle => 'Digitale Integritätssignatur';

  @override
  String get digitallySignSubtitle =>
      'Dokument mit Geräteschlüssel signieren, um zu beweisen, dass es nicht geändert wurde.';

  @override
  String get digitallySignEnabledHint => 'Digitale Signatur wird angewendet';

  @override
  String get myIdentityTitle => 'Meine Geräte-Identität';

  @override
  String get deviceNameLabel => 'Geräte- / Inhabername';

  @override
  String get identityNameLabel => 'Name';

  @override
  String get myPublicKeyLabel => 'Öffentlicher Schlüssel (Ihre digitale ID):';

  @override
  String get copyPublicKey => 'Öffentlichen Schlüssel kopieren';

  @override
  String get sharePublicKey => 'Öffentlichen Schlüssel teilen';

  @override
  String get generateQrKey => 'QR-Code generieren';

  @override
  String get qrIdentityTitle => 'Identitäts-QR-Code';

  @override
  String get publicKeyCopied =>
      'Öffentlicher Schlüssel in die Zwischenablage kopiert';

  @override
  String get bookmarkSaved =>
      'Identität erfolgreich als Lesezeichen gespeichert';

  @override
  String get signatureVerified =>
      '✅ Integrität verifiziert: Dokument ist authentisch';

  @override
  String get tamperDetected =>
      '❌ MANIPULATION ERKANNT: Dokument wurde geändert';

  @override
  String senderOwnerLabel(String name) {
    return 'Absender: $name';
  }

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
  String get processingErrorsTitle => 'Verarbeitungsfehler';

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
  String get progressSigningPdf => 'PDF wird digital signiert...';

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
  String get themeAmoled => 'Amoled Schwarz';

  @override
  String get resetProfiles => 'Profile zurücksetzen';

  @override
  String resetProfileConfirm(String profile) {
    return '$profile auf Werkseinstellungen zurücksetzen?';
  }

  @override
  String profileSaved(String profile) {
    return 'Aktuelle Konfiguration als Standard für $profile gespeichert';
  }

  @override
  String profileReset(String profile) {
    return 'Profil $profile auf Werkseinstellungen zurückgesetzt';
  }

  @override
  String get previewModeOriginal => 'Original';

  @override
  String get previewModeProcessed => 'Verarbeitet';

  @override
  String get previewModeHeatmap => 'Manipulations-Heatmap';

  @override
  String get authenticityVerified => 'AUTHENTIZITÄT VERIFIZIERT';

  @override
  String get fullAuthenticityConfirmed => 'VOLLE AUTHENTIZITÄT BESTÄTIGT';

  @override
  String get partialAuthenticity => 'TEILWEISE AUTHENTIZITÄT';

  @override
  String get tamperingDetected => 'MANIPULATION ERKANNT';

  @override
  String get forensicLayerContent => 'Inhalt (Bild + versteckte Daten)';

  @override
  String get forensicLayerSource => 'Quelle (sichtbares Bild)';

  @override
  String get forensicStatusValid => 'GÜLTIG';

  @override
  String get forensicStatusModified => 'GEÄNDERT';

  @override
  String get verifFullIntegrity =>
      'Vollständige Integrität bestätigt (Bild + versteckte Daten).';

  @override
  String get verifPartialIntegrity =>
      'Visuelle Integrität bestätigt, aber die versteckte Steganographie wurde geändert oder beschädigt.';

  @override
  String get verifTamperingDetected =>
      'Forensische Prüfung fehlgeschlagen. Sowohl visuelle Pixel als auch versteckte Daten scheinen geändert worden zu sein.';

  @override
  String get onboardingStepTitle => 'So funktioniert es';

  @override
  String get onboardingStep1 =>
      '1. Wählen Sie ein Profil für Ihren Anwendungsfall.';

  @override
  String get onboardingStep2 => '2. Importieren Sie Bilder oder PDF-Dateien.';

  @override
  String get onboardingStep2NoCamera =>
      '2. Wählen Sie Bilder oder PDF-Dateien aus.';

  @override
  String get onboardingStep3 =>
      '3. Klicken Sie auf Anwenden, um Wasserzeichen zu generieren.';

  @override
  String get onboardingStep4 => '4. Teilen oder Speichern Sie die Ergebnisse.';

  @override
  String get onboardingExpertTitle => 'Profile & Optionen';

  @override
  String get onboardingExpertModeTitle => 'Expertenmodus';

  @override
  String get onboardingSaveProfileTitle => 'Presets speichern';

  @override
  String get onboardingLiveStatusTitle => 'Sicherheitsstatus';

  @override
  String get onboardingFileAnalyzerTitle => 'Verifizierung';

  @override
  String get onboardingProfileSave =>
      'Langes Drücken auf ein Profil speichert die aktuelle Konfiguration als Standard.';

  @override
  String get onboardingExpertNote =>
      'Expertenmodus (oben rechts) schaltet erweiterte Einstellungen frei';

  @override
  String get onboardingOptionsNote =>
      'Aktive Optionen sehen (Doppeltippen zum Konfigurieren)';

  @override
  String get onboardingFileAnalyzerNote =>
      'Datei-Analysator zur Prüfung auf versteckte Signaturen oder Dateien';

  @override
  String get onboardingQrCodeNote =>
      'Kontaktdaten, Links oder Metadaten per QR-Code einbetten.';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingDone => 'Verstanden';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get showGuide => 'Anleitung anzeigen';

  @override
  String get activeOptionsHelpTitle => 'Aktive Sicherheitsoptionen';

  @override
  String get identityBookmarksTitle => 'Signaturkontakte';

  @override
  String get bookmarkNameLabel => 'Identitätsname';

  @override
  String get identityKeyLabel => 'Signatur (öffentlicher Schlüssel)';

  @override
  String get addIdentity => 'Kontakt';

  @override
  String get addWithQrCode => 'QR-Code';

  @override
  String get removeIdentityConfirm => 'Dieses Identitätslesezeichen entfernen?';

  @override
  String get invalidQrCode => 'Ungültiger Identitäts-QR-Code';

  @override
  String get scannerTitle => 'QR-Code für öffentlichen Schlüssel scannen';

  @override
  String get exportConfigTitle => 'Konfig & Schlüssel exportieren';

  @override
  String get importConfigTitle => 'Konfig & Schlüssel importieren';

  @override
  String get exportConfigDesc =>
      'Dies erstellt eine passwortgeschützte ZIP-Datei mit all Ihren Einstellungen und digitalen Identitätsschlüsseln.';

  @override
  String get exportConfigButton => 'Exportieren';

  @override
  String get importConfigButton => 'Importieren';

  @override
  String configExportSuccess(Object path) {
    return 'Konfiguration erfolgreich exportiert nach: $path';
  }

  @override
  String get longPressToConfigure => 'Lange drücken zum Konfigurieren';

  @override
  String get longPressConfigure => 'Lange drücken: konfigurieren';

  @override
  String get noBookmarksYet => 'Noch keine Lesezeichen.';

  @override
  String get statusEnabled => 'Status: Aktiviert';

  @override
  String get statusDisabled => 'Status: Deaktiviert';

  @override
  String get doubleTapToToggle => 'Doppeltippen zum Umschalten';

  @override
  String get requiresSteganography => 'Erfordert Steganographie';

  @override
  String get preserveMetadata => 'Metadaten beibehalten';

  @override
  String get tapInfo => 'Tippen: Info';

  @override
  String get doubleTapToggle => 'Doppeltippen: Umschalten';

  @override
  String get tapInfoDoubleTapToggle =>
      'Tippen: Info • Doppeltippen: Umschalten';

  @override
  String statusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get enabled => 'aktiviert';

  @override
  String get disabled => 'deaktiviert';

  @override
  String get localShareTitle => 'Lokale Netzwerkfreigabe';

  @override
  String get sendTab => 'Senden';

  @override
  String get receiveTab => 'Empfangen/Senden';

  @override
  String sendingFile(Object name) {
    return 'Senden von: $name';
  }

  @override
  String get noFilesToSend =>
      'Verarbeiten Sie zuerst einige Dateien, um sie zu senden.';

  @override
  String get receivingFile => 'Datei empfangen';

  @override
  String get connectingToServer => 'Verbindung zum Absender...';

  @override
  String downloadingFile(Object name) {
    return 'Herunterladen: $name';
  }

  @override
  String get saveToWhere => 'Datei speichern unter...';

  @override
  String get localShareInstructions =>
      'Der Empfänger muss sich im selben Netzwerk befinden. Scannen Sie den QR-Code zum Herunterladen.';

  @override
  String get sendAllZip => 'Alles als ZIP senden';

  @override
  String get generatingKey => 'Verschlüsselungsschlüssel wird generiert...';

  @override
  String get encryptingPayload => 'Daten werden verschlüsselt (AES-256)...';

  @override
  String get startingServer => 'Lokaler HTTP-Server wird gestartet...';

  @override
  String get decryptingPayload => 'Daten werden entschlüsselt...';

  @override
  String get payloadEncrypted => 'Daten verschlüsselt und gesichert';

  @override
  String get connectionEstablished => 'Mit Absender verbunden';

  @override
  String serverStarted(Object port) {
    return 'Server läuft auf Port $port';
  }

  @override
  String get enableEncryption => 'Ende-zu-Ende-Verschlüsselung verwenden';

  @override
  String downloadSpeed(Object speed) {
    return 'Geschwindigkeit: $speed';
  }

  @override
  String get pickAnyFile => 'Benutzerdefinierte Datei auswählen';

  @override
  String get encryptionDisabledWarning =>
      'Warnung: Daten werden unverschlüsselt im lokalen Netzwerk gesendet.';

  @override
  String get noCameraOption => 'Keine Kamera? QR zum Empfangen zeigen';

  @override
  String get showQrToReceive =>
      'Scannen Sie dies vom sendenden Gerät, um eine Datei hierher zu übertragen.';

  @override
  String pushingFile(Object device) {
    return 'Datei wird an $device übertragen...';
  }

  @override
  String get manualUrlLabel => 'Oder geben Sie diese URL in einen Browser ein:';

  @override
  String get waitingForFile => 'Warten auf eingehende Datei...';

  @override
  String fileReceived(Object address) {
    return 'Datei von $address erhalten';
  }
}
