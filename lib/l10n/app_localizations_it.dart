// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'SecureMark';

  @override
  String get emptyPreviewHint =>
      'Inserisci il testo della filigrana e scegli uno o più file immagine o PDF';

  @override
  String get selectedPreviewHint =>
      'File selezionati. Clicca su Applica SecureMark per generare le anteprime';

  @override
  String selectedFilesLabel(int count) {
    return 'File selezionati ($count)';
  }

  @override
  String get clickApplyToPreview =>
      'Clicca su \"Applica SecureMark\" per generare le anteprime';

  @override
  String get previewUnavailable => 'Anteprima non disponibile';

  @override
  String swipeHint(int current, int total) {
    return 'Scorri a sinistra per il successivo, a destra per il precedente ($current/$total)';
  }

  @override
  String get processingFile => 'Elaborazione file...';

  @override
  String get applyingWatermark => 'Applicazione filigrana...';

  @override
  String get processingValidating => 'Validazione file...';

  @override
  String get processingProcessing => 'Elaborazione file...';

  @override
  String get processingCached => 'Recuperato dalla cache';

  @override
  String get processingComplete => 'Elaborazione completata';

  @override
  String get processingFlattening => 'Rasterizzazione PDF (appiattimento)...';

  @override
  String get authorFooter => 'Autore: Antoine Giniès';

  @override
  String get pickFiles => 'Immagini o PDF';

  @override
  String get takePhoto => 'Scatta Foto';

  @override
  String get takePhotoSubtitle => 'Uso diretto';

  @override
  String selectedFile(String name) {
    return 'File selezionato: $name';
  }

  @override
  String selectedFiles(int count) {
    return 'File selezionati: $count';
  }

  @override
  String get applyWatermark => 'Applica SecureMark';

  @override
  String get saveAll => 'Salva tutto';

  @override
  String get shareAll => 'Condividi tutto';

  @override
  String get reset => 'Reset';

  @override
  String get watermarkTypeText => 'Testo';

  @override
  String get watermarkTypeImage => 'Immagine/Logo';

  @override
  String get selectWatermarkImage => 'Seleziona Logo';

  @override
  String selectedWatermarkImage(String name) {
    return '$name';
  }

  @override
  String get watermarkTextLabel => 'Testo da timbrare (+Data-ora)';

  @override
  String get watermarkTextHint => 'Inserisci il testo da timbrare';

  @override
  String get randomColor => 'Colore casuale';

  @override
  String get selectedColor => 'Colore selezionato';

  @override
  String transparencyValue(int value) {
    return 'Trasparenza filigrana: $value%';
  }

  @override
  String densityValue(int value) {
    return 'Densità: $value%';
  }

  @override
  String get droppedPathUnavailable =>
      'I percorsi dei file rilasciati non sono disponibili.';

  @override
  String get desktopDropArea => 'Rilascia i file qui';

  @override
  String get pickerLabel => 'Immagini e PDF';

  @override
  String processingCount(int count) {
    return 'Elaborazione di 1/$count file...';
  }

  @override
  String processingNamedFile(int current, int total, String name) {
    return 'Elaborazione $current/$total: $name';
  }

  @override
  String get processingFailed => 'File non supportato o elaborazione fallita.';

  @override
  String errorPrefix(String error) {
    return 'Errore: $error';
  }

  @override
  String savedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file salvati',
      one: '1 file salvato',
    );
    return '$_temp0.';
  }

  @override
  String get shareSubject => 'File con filigrana';

  @override
  String get shareText => 'Condiviso da SecureMark';

  @override
  String sharedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file condivisi',
      one: '1 file condiviso',
    );
    return '$_temp0.';
  }

  @override
  String shareOpenedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file',
      one: '1 file',
    );
    return 'Schermata di condivisione aperta per $_temp0.';
  }

  @override
  String get cancel => 'Annulla';

  @override
  String get saveLocationInfo =>
      'I file saranno salvati nella stessa cartella degli originali con il prefisso \'securemark-\'';

  @override
  String get expertOptions => 'Opzioni esperte';

  @override
  String fontSizeValue(int value) {
    return 'Dimensione carattere: ${value}px';
  }

  @override
  String logoSizeLabel(int value) {
    return 'Dimensione Logo: ${value}px';
  }

  @override
  String jpegQualityValue(int value) {
    return 'Qualità JPEG: $value%';
  }

  @override
  String imageResizingLabel(String size) {
    return 'Ridimensionamento immagine: $size';
  }

  @override
  String get imageResizingEnabledHint =>
      'Il ridimensionamento dell\'immagine è abilitato';

  @override
  String get resizeNone => 'Nessuno (Originale)';

  @override
  String pixelUnit(int value) {
    return '$value px';
  }

  @override
  String get includeTimestampFilename => 'Includi data e ora nel nome del file';

  @override
  String get preserveExifData => 'Preserva i metadati del file (EXIF/PDF Info)';

  @override
  String get preserveMetadataEnabledHint =>
      'I metadati del file verranno preservati';

  @override
  String get rasterizePdfTitle => 'Rasterizza PDF (Appiattisci)';

  @override
  String get rasterizePdfSubtitle =>
      'Converti le pagine PDF in immagini per la massima sicurezza (dimensioni maggiori e più lento)';

  @override
  String get rasterizePdfEnabledHint =>
      'Il PDF verrà rasterizzato (appiattito)';

  @override
  String get steganographyTitle => 'Steganografia (Firma invisibile)';

  @override
  String get steganographySubtitle =>
      'Incorpora il testo segretamente nei pixel.';

  @override
  String get robustSteganographyTitle => 'Filigrana robusta (Dominio DCT)';

  @override
  String get robustSteganographySubtitle =>
      'Sperimentale: resiste meglio alla ricompressione e al ridimensionamento rispetto a LSB.';

  @override
  String get filePrefixLabel => 'Prefisso file';

  @override
  String get filePrefixHint => 'es. filigrana-';

  @override
  String get resetExpertHint =>
      'Questo ripristinerà tutte le impostazioni esperte e il prefisso del file ai valori predefiniti.';

  @override
  String get fontStyleLabel => 'Stile carattere';

  @override
  String get fontSelectionNote =>
      'Nota: utilizzo di font bitmap ottimizzati per un rendering multipiattaforma veloce.';

  @override
  String get fontSelectionNoteGoogle =>
      'Nota: utilizzo di Google Fonts per una tipografia migliorata. Richiede Internet per il primo utilizzo.';

  @override
  String get fontSelectionNoteAsset =>
      'Nota: utilizzo di un font TTF personalizzato per una tipografia migliorata. Richiede i file del font in assets/fonts/.';

  @override
  String get resetToDefaults => 'Ripristina predefiniti';

  @override
  String outputDirectoryLabel(String path) {
    return 'Cartella di output: $path';
  }

  @override
  String get selectOutputDirectory => 'Seleziona cartella di output';

  @override
  String logoDirectoryLabel(String path) {
    return 'Cartella logo: $path';
  }

  @override
  String get selectLogoDirectory => 'Seleziona cartella logo';

  @override
  String get viewLogs => 'Visualizza log';

  @override
  String get saveLogs => 'Salva log';

  @override
  String logsSaved(String path) {
    return 'Log salvati in: $path';
  }

  @override
  String get appLogs => 'Log dell\'app';

  @override
  String get noLogsYet => 'Ancora nessun log';

  @override
  String get openGitHub => 'Apri repository GitHub';

  @override
  String get close => 'Chiudi';

  @override
  String get aboutApp => 'Informazioni su SecureMark';

  @override
  String get appDescription =>
      'Un\'applicazione professionale per proteggere i documenti con filigrane per una condivisione sicura.';

  @override
  String authorLabel(String name) {
    return 'Autore: $name';
  }

  @override
  String get checkForUpdates => 'Controlla aggiornamenti';

  @override
  String get checkingForUpdates => 'Controllo aggiornamenti...';

  @override
  String get upToDate => 'Stai utilizzando l\'ultima versione.';

  @override
  String updateAvailable(String version) {
    return 'È disponibile una nuova versione ($version)!';
  }

  @override
  String get updateCheckError => 'Impossibile controllare gli aggiornamenti.';

  @override
  String get githubRepository => 'Repository GitHub';

  @override
  String get privacyPolicy => 'Informativa sulla privacy';

  @override
  String get viewUpdate => 'Visualizza';

  @override
  String get analyzeFile => 'Analizza file (LSB)';

  @override
  String get fileAnalyzerTitle => 'Analizzatore file (LSB)';

  @override
  String get fileAnalyzerDescription =>
      'Seleziona un file per cercare firme SecureMark nascoste.';

  @override
  String get pickAndAnalyze => 'Scegli e analizza';

  @override
  String encryptedFileDetected(Object name) {
    return '🔐 Rilevato file crittografato: $name. Inserisci la password corretta.';
  }

  @override
  String hiddenFileDetected(Object name, Object size) {
    return '📁 Rilevato file nascosto: $name ($size)';
  }

  @override
  String get encryptedSignatureDetected =>
      '🔐 Rilevata firma crittografata. Inserisci la password corretta.';

  @override
  String signatureFound(String message) {
    return '✅ Firma trovata: \"$message\"';
  }

  @override
  String robustSignatureFound(String message) {
    return '💪 Firma robusta trovata: \"$message\"';
  }

  @override
  String get noSignatureFound =>
      '❌ Nessuna firma SecureMark rilevata in questo file.';

  @override
  String analysisError(String error) {
    return 'Errore durante l\'analisi: $error';
  }

  @override
  String get analysisResult => 'Risultato:';

  @override
  String get steganographyVerified => 'Steganografia verificata';

  @override
  String get steganographyVerificationFailed =>
      'Verifica steganografia fallita';

  @override
  String get steganographyEnabledHint =>
      'La steganografia è abilitata e sarà applicata';

  @override
  String get hideFileWithSteganographyTitle =>
      'Nascondi un file (sperimentale)';

  @override
  String get hideFileWithSteganographySubtitle =>
      'Incorpora un intero file all\'interno dell\'immagine (potrebbe aumentare le dimensioni dell\'output)';

  @override
  String get hideFileEnabledHint => 'Un file nascosto verrà incorporato';

  @override
  String get selectFileToHide => 'Seleziona il file da nascondere';

  @override
  String selectedHiddenFile(String name) {
    return 'File nascosto: $name';
  }

  @override
  String get hiddenFileSecurityWarning =>
      'Avviso di sicurezza: i file nascosti sono sicuri solo se crittografati prima dell\'incorporamento. La steganografia nasconde ma non crittografa i dati.';

  @override
  String get steganographyPasswordLabel => 'Password di crittografia';

  @override
  String get steganographyPasswordHint =>
      'Inserisci la password per proteggere il file nascosto';

  @override
  String get steganographyPasswordNote =>
      'Nota: questa password sarà richiesta per estrarre il file nascosto utilizzando SecureMark. Utilizza la crittografia AES-256.';

  @override
  String get steganographyZipNote =>
      'Importante: se utilizzi la steganografia e condividi questi file tramite WhatsApp, Signal o altre app che comprimono le immagini, è necessario abilitare la compressione ZIP o comprimerli manualmente. La condivisione diretta di solito distrugge la steganografia invisibile.';

  @override
  String get steganographyImageOnlyNote =>
      'Note: Steganography (invisible signatures and hidden files) is only supported for image files (JPG, PNG, WebP). It will be skipped for PDF files.';

  @override
  String get steganographyTextLabel => 'Custom Steganography Signature';

  @override
  String get steganographyTextHint =>
      'Enter custom text to hide (defaults to watermark text if empty)';

  @override
  String get zipAllFiles => 'Zippa tutti i file';

  @override
  String get zipEnabledHint =>
      'Compressione ZIP abilitata per la condivisione. NOTA: le applicazioni di terze parti (WhatsApp, Signal, ecc.) comprimono le immagini, il che può distruggere le firme di steganografia. Abilitate ZIP per evitare la perdita di firme.';

  @override
  String get zipDisabledHint => 'Compressione ZIP disabilitata';

  @override
  String get qrWatermarkTitle => 'Filigrana codice QR';

  @override
  String get enableQrWatermark => 'Abilita codice QR';

  @override
  String get enableQrWatermarkSubtitle => 'Incorpora metadati in un codice QR';

  @override
  String get qrMode => 'Modalità codice QR';

  @override
  String get qrVisibleMode => 'Codice QR visibile';

  @override
  String get qrVisibleModeDesc => 'Mostra il codice QR sull\'immagine';

  @override
  String get qrAuthorLabel => 'Nome autore';

  @override
  String get qrAuthorHint => 'es. Mario Rossi';

  @override
  String get qrUrlLabel => 'URL o sito web';

  @override
  String get qrUrlHint => 'es. https://example.com';

  @override
  String get qrVisibleOptions => 'Opzioni QR visibile';

  @override
  String get qrPositionLabel => 'Posizione codice QR';

  @override
  String get qrPosTopLeft => 'In alto a sinistra';

  @override
  String get qrPosTopRight => 'In alto a destra';

  @override
  String get qrPosBottomLeft => 'In basso a sinistra';

  @override
  String get qrPosBottomRight => 'In basso a destra';

  @override
  String get qrPosCenter => 'Centro';

  @override
  String qrSizeValue(int value) {
    return 'Dimensione codice QR: ${value}px';
  }

  @override
  String qrOpacityValue(int value) {
    return 'Opacità codice QR: $value%';
  }

  @override
  String receivedFilesFromSharing(int count) {
    return '📥 Ricevuti $count file dalla condivisione';
  }

  @override
  String get unsupportedSharedFormat =>
      '⚠️ I file condivisi non sono in un formato supportato (JPG, PNG, WebP, PDF, HEIC/HEIF)';

  @override
  String get signatureCopied => 'Firma copiata negli appunti';

  @override
  String get copySignature => 'Copia firma';

  @override
  String get saveHiddenFile => 'Salva file nascosto';

  @override
  String fileSaved(String name) {
    return 'File salvato: $name';
  }

  @override
  String errorSavingFile(String error) {
    return 'Errore durante il salvataggio del file: $error';
  }

  @override
  String antiAiProtectionValue(int value) {
    return 'Protezione Anti-IA: $value%';
  }

  @override
  String get antiAiProtectionNote =>
      'Nota: una protezione più elevata aumenta significativamente il tempo necessario per generare l\'immagine protetta.';

  @override
  String get antiAiEnabledHint => 'La protezione Anti-IA è abilitata';

  @override
  String get aiCloakingTitle => 'Cloaking IA (Adversarial)';

  @override
  String get aiCloakingSubtitle =>
      'Inietta rumore invisibile per disturbare l\'addestramento dell\'IA e il furto di stile.';

  @override
  String get aiCloakingEnabledHint => 'Il Cloaking IA è attivo';

  @override
  String get qrContentType => 'Tipo di contenuto QR';

  @override
  String get qrTypeMetadata => 'Metadati (JSON)';

  @override
  String get qrTypeUrl => 'Reindirizzamento sito web';

  @override
  String get qrTypeVCard => 'Contatto (vCard)';

  @override
  String get vCardFirstName => 'Nome';

  @override
  String get vCardLastName => 'Cognome';

  @override
  String get vCardPhone => 'Numero di telefono';

  @override
  String get vCardEmail => 'Indirizzo email';

  @override
  String get vCardOrg => 'Organizzazione';

  @override
  String get invalidUrlError =>
      'Inserisci un URL valido (es. https://example.com)';

  @override
  String get noQrFound => '❌ Nessun codice QR rilevato';

  @override
  String get abToggleTooltipOriginal => 'Mostra originale';

  @override
  String get abToggleTooltipProcessed => 'Mostra elaborato';

  @override
  String get processingCancelled => 'Elaborazione annullata';

  @override
  String processingStatusMultiple(int successCount, int failedCount) {
    return 'Elaborati correttamente $successCount file. $failedCount file falliti.';
  }

  @override
  String get processingFailedSingle =>
      'Impossibile elaborare il file. Controlla il formato del file e riprova.';

  @override
  String processingFailedMultiple(int count) {
    return 'Impossibile elaborare $count file. Controlla i formati dei file e riprova.';
  }

  @override
  String fileSavedTo(String path) {
    return 'File salvato in: $path';
  }

  @override
  String get saveFailedGeneral =>
      'Impossibile salvare i file. Controlla i permessi e lo spazio di archiviazione.';

  @override
  String saveStatusMultiple(int successCount, int failedCount) {
    return 'Salvati $successCount file. $failedCount file falliti.';
  }

  @override
  String get filesSavedTitle => 'File salvati';

  @override
  String successfullySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file salvati correttamente',
      one: '1 file salvato correttamente',
    );
    return '$_temp0:';
  }

  @override
  String failedSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'impossibile salvare $count file',
      one: 'impossibile salvare 1 file',
    );
    return '$_temp0:';
  }

  @override
  String willSaveAsIn(String name, String path) {
    return 'Sarà salvato come: $name in $path/';
  }

  @override
  String willSaveMultipleIn(int count, String path) {
    return 'Saranno salvati $count file in: $path/';
  }

  @override
  String get savingFiles => 'Salvataggio file...';

  @override
  String errorSavingFiles(String error) {
    return 'Errore durante il salvataggio dei file: $error';
  }

  @override
  String get foregroundTaskTitle => 'Elaborazione SecureMark';

  @override
  String get foregroundTaskDescription =>
      'Mostra l\'avanzamento della filigrana del documento';

  @override
  String foregroundTaskUpdate(int current, int total, String name) {
    return 'Elaborazione file $current di $total: $name';
  }

  @override
  String get fileTooLargeTitle => 'File troppo grande';

  @override
  String fileTooLargeMessage(String fileName, String fileSize,
      String imageDimensions, String maxCapacity) {
    return 'Il file \"$fileName\" ($fileSize KB) è troppo grande per essere nascosto in questa immagine ($imageDimensions).\n\nCapacità massima: $maxCapacity KB\n\nSi prega di utilizzare un\'immagine più grande o comprimere/ridurre la dimensione del file.';
  }

  @override
  String get loadingSelectedFiles => 'Caricamento dei file selezionati...';

  @override
  String get profileLabel => 'Profilo';

  @override
  String get profileDescription => 'Preselezioni rapide per casi d\'uso comuni';

  @override
  String get profileNone => 'Custom';

  @override
  String get profileSecureIdentity => 'Identità';

  @override
  String get profileOnlineImage => 'Immagine';

  @override
  String get profileQrCode => 'QR Code';

  @override
  String get profileShareDocument => 'Doc';

  @override
  String get progressValidating => 'Validazione file...';

  @override
  String get progressFromCache => 'Recuperato dalla cache';

  @override
  String get progressDetectingType => 'Rilevamento tipo di file...';

  @override
  String get progressStarting => 'Avvio elaborazione...';

  @override
  String get progressComplete => 'Elaborazione completata';

  @override
  String get progressReadingImage => 'Lettura file immagine...';

  @override
  String get progressRenderingFont => 'Rendering del carattere...';

  @override
  String get progressFinalizingImage => 'Finalizzazione immagine...';

  @override
  String get progressVerifyingStegano => 'Verifica steganografia...';

  @override
  String get progressSteganoVerified => 'Steganografia verificata';

  @override
  String get progressSteganoFailed => 'Verifica steganografica fallita';

  @override
  String get progressRasterizing => 'Rasterizzazione PDF (appiattimento)...';

  @override
  String get progressReadingPdf => 'Lettura file PDF...';

  @override
  String get progressAddingLayer => 'Aggiunta livello filigrana...';

  @override
  String get progressFinalizingPdf => 'Finalizzazione PDF...';

  @override
  String get progressParsingPdf => 'Analisi documento PDF...';

  @override
  String get progressDecodingImage => 'Decodifica immagine...';

  @override
  String get progressResizingImage => 'Ridimensionamento immagine...';

  @override
  String get progressApplyingCloaking => 'Applicazione cloaking IA...';

  @override
  String get progressApplyingWatermark => 'Applicazione filigrana...';

  @override
  String get progressEmbeddingRobust =>
      'Incorporamento filigrana robusta (DCT)...';

  @override
  String get progressHidingFile =>
      'Nascondiglio file nell\'immagine (steganografia)...';

  @override
  String get progressEmbeddingLsb => 'Incorporamento firma invisibile (LSB)...';

  @override
  String get progressEncodingImage => 'Codifica immagine...';

  @override
  String get progressGeneratingQr => 'Generazione codice QR...';

  @override
  String get progressEmbeddingQr => 'Incorporamento codice QR...';

  @override
  String get progressQrEmbedded => 'Codice QR incorporato';

  @override
  String progressWatermarkingPage(int current, int total) {
    return 'Filigrana pagina $current/$total...';
  }

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeSystem => 'Predefinito di sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get themeAmoled => 'Nero AMOLED';

  @override
  String get resetProfiles => 'Ripristina profili';

  @override
  String resetProfileConfirm(String profile) {
    return 'Ripristinare $profile ai valori di fabbrica?';
  }

  @override
  String profileSaved(String profile) {
    return 'Configurazione attuale salvata come predefinita per $profile';
  }

  @override
  String profileReset(String profile) {
    return 'Profilo $profile ripristinato ai valori di fabbrica';
  }

  @override
  String get previewModeOriginal => 'Original';

  @override
  String get previewModeProcessed => 'Processed';

  @override
  String get previewModeHeatmap => 'Tamper Heatmap';

  @override
  String get authenticityVerified => 'AUTHENTICITY VERIFIED';

  @override
  String get fullAuthenticityConfirmed => 'FULL AUTHENTICITY CONFIRMED';

  @override
  String get partialAuthenticity => 'PARTIAL AUTHENTICITY';

  @override
  String get tamperingDetected => 'TAMPERING DETECTED';

  @override
  String get forensicLayerContent => 'Content (Image + Hidden Data)';

  @override
  String get forensicLayerSource => 'Source (Visible Image)';

  @override
  String get forensicStatusValid => 'VALID';

  @override
  String get forensicStatusModified => 'MODIFIED';

  @override
  String get verifFullIntegrity =>
      'Full integrity confirmed (Image + Hidden Data).';

  @override
  String get verifPartialIntegrity =>
      'Visual integrity confirmed, but hidden steganography has been modified or corrupted.';

  @override
  String get verifTamperingDetected =>
      'Forensic check failed. Both visual pixels and hidden data appear modified.';
}
