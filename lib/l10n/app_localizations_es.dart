// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'SecureMark';

  @override
  String get emptyPreviewHint =>
      'Ingresa el texto de la marca de agua y elige una o más imágenes o archivos PDF';

  @override
  String get selectedPreviewHint =>
      'Archivos seleccionados. Haz clic en Aplicar SecureMark para generar las vistas previas';

  @override
  String selectedFilesLabel(int count) {
    return 'Archivos seleccionados ($count)';
  }

  @override
  String get clickApplyToPreview =>
      'Haz clic en \"Aplicar SecureMark\" para generar las vistas previas';

  @override
  String get previewUnavailable => 'Vista previa no disponible';

  @override
  String swipeHint(int current, int total) {
    return 'Desliza a la izquierda para el siguiente, a la derecha para el anterior ($current/$total)';
  }

  @override
  String get processingFile => 'Procesando archivo...';

  @override
  String get applyingWatermark => 'Aplicando marca de agua...';

  @override
  String get processingValidating => 'Validando archivo...';

  @override
  String get processingProcessing => 'Procesando archivo...';

  @override
  String get processingCached => 'Obtenido de la caché';

  @override
  String get processingComplete => 'Procesamiento completado';

  @override
  String get processingFlattening => 'Rasterizando PDF (aplana)...';

  @override
  String get authorFooter => 'Autor: Antoine Giniès';

  @override
  String get pickFiles => 'Imágenes o PDF';

  @override
  String get takePhoto => 'Foto clásica';

  @override
  String get takePhotoSubtitle => 'Captura de cámara estándar';

  @override
  String get scanDocument => 'Escanear documento';

  @override
  String get scanDocumentSubtitle => 'Escaneo con detección de bordes';

  @override
  String get captureMenuTitle => 'Método de captura';

  @override
  String selectedFile(String name) {
    return 'Archivo seleccionado: $name';
  }

  @override
  String selectedFiles(int count) {
    return 'Archivos seleccionados: $count';
  }

  @override
  String get applyWatermark => 'Aplicar SecureMark';

  @override
  String get saveAll => 'Guardar todo';

  @override
  String get shareAll => 'Compartir todo';

  @override
  String get reset => 'Reiniciar';

  @override
  String get watermarkTypeText => 'Texto';

  @override
  String get watermarkTypeImage => 'Imagen/Logo';

  @override
  String get selectWatermarkImage => 'Seleccionar imagen de logo';

  @override
  String selectedWatermarkImage(String name) {
    return '$name';
  }

  @override
  String get watermarkTextLabel => 'Texto para estampar (+Fecha-hora)';

  @override
  String get watermarkTextHint => 'Ingresa el texto para estampar';

  @override
  String get randomColor => 'Color aleatorio';

  @override
  String get selectedColor => 'Color seleccionado';

  @override
  String transparencyValue(int value) {
    return 'Transparencia de marca de agua: $value%';
  }

  @override
  String densityValue(int value) {
    return 'Densidad: $value%';
  }

  @override
  String get droppedPathUnavailable =>
      'Las rutas de archivo soltados no están disponibles.';

  @override
  String get desktopDropArea => 'Suelta los archivos aquí';

  @override
  String get pickerLabel => 'Imágenes y PDFs';

  @override
  String processingCount(int count) {
    return 'Procesando 1/$count archivos...';
  }

  @override
  String processingNamedFile(int current, int total, String name) {
    return 'Procesando $current/$total: $name';
  }

  @override
  String get processingFailed =>
      'Archivo no compatible o fallo en el procesamiento.';

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String savedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos guardados',
      one: '1 archivo guardado',
    );
    return '$_temp0.';
  }

  @override
  String get shareSubject => 'Archivos con marca de agua';

  @override
  String get shareText => 'Compartido desde SecureMark';

  @override
  String sharedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos Compartidos',
      one: '1 archivo compartido',
    );
    return '$_temp0.';
  }

  @override
  String shareOpenedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
    );
    return 'Hoja de compartir abierta para $_temp0.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get saveLocationInfo =>
      'Los archivos se guardarán en la misma carpeta que los originales con prefijo \'securemark-\'';

  @override
  String get expertOptions => 'Opciones de experto';

  @override
  String fontSizeValue(int value) {
    return 'Tamaño de fuente: ${value}px';
  }

  @override
  String logoSizeLabel(int value) {
    return 'Tamaño del Logo: ${value}px';
  }

  @override
  String jpegQualityValue(int value) {
    return 'Calidad JPEG: $value%';
  }

  @override
  String imageResizingLabel(String size) {
    return 'Redimensionar imagen: $size';
  }

  @override
  String get imageResizingEnabledHint =>
      'El redimensionamiento de imagen está habilitado';

  @override
  String get resizeNone => 'Ninguno (Original)';

  @override
  String pixelUnit(int value) {
    return '$value px';
  }

  @override
  String get includeTimestampFilename =>
      'Incluir fecha y hora en el nombre del archivo';

  @override
  String get preserveExifData =>
      'Preservar metadatos del archivo (EXIF/Info PDF)';

  @override
  String get preserveMetadataEnabledHint =>
      'Los metadatos del archivo se preservarán';

  @override
  String get rasterizePdfTitle => 'Rasterizar PDF (Aplanar)';

  @override
  String get rasterizePdfSubtitle =>
      'Convertir páginas PDF en imágenes para máxima seguridad (más tamaño y más lento)';

  @override
  String get rasterizePdfEnabledHint => 'El PDF será rasterizado (aplanado)';

  @override
  String get steganographyTitle => 'Esteganografía (Firma invisible)';

  @override
  String get steganographySubtitle => 'Incluye texto secretamente en píxeles.';

  @override
  String get robustSteganographyTitle => 'Marca de agua robusta (Dominio DCT)';

  @override
  String get robustSteganographySubtitle =>
      'Experimental: sobrevive mejor a la recompression y redimensionamiento que el LSB.';

  @override
  String get filePrefixLabel => 'Prefijo de archivo';

  @override
  String get filePrefixHint => 'ej. marca-de-agua-';

  @override
  String get resetExpertHint =>
      'Esto reiniciará todas las opciones de experto y el prefijo de archivo a valores predeterminados.';

  @override
  String get fontStyleLabel => 'Estilo de fuente';

  @override
  String get fontSelectionNote =>
      'Nota: Uso de fuentes de mapa de bits optimizadas para renderizado rápido multiplataforma.';

  @override
  String get fontSelectionNoteGoogle =>
      'Nota: Uso de Google Fonts para una tipografía mejorada. Requiere internet para el primer uso.';

  @override
  String get fontSelectionNoteAsset =>
      'Nota: Uso de fuente TTF personalizado para una tipografía mejorada. Requiere archivos de fuente en assets/fonts/.';

  @override
  String get resetToDefaults => 'Reiniciar a predeterminados';

  @override
  String outputDirectoryLabel(String path) {
    return 'Directorio de salida: $path';
  }

  @override
  String get selectOutputDirectory => 'Seleccionar directorio de salida';

  @override
  String logoDirectoryLabel(String path) {
    return 'Directorio de logos: $path';
  }

  @override
  String get selectLogoDirectory => 'Seleccionar directorio de logos';

  @override
  String get viewLogs => 'Ver registros';

  @override
  String get saveLogs => 'Guardar registros';

  @override
  String logsSaved(String path) {
    return 'Registros guardados en: $path';
  }

  @override
  String get appLogs => 'Registro de aplicación';

  @override
  String get noLogsYet => 'Aún ningún registro';

  @override
  String get openGitHub => 'Ver repositorio de GitHub';

  @override
  String get close => 'Cerrar';

  @override
  String get aboutApp => 'Acerca de SecureMark';

  @override
  String get appDescription =>
      'Una aplicación profesional para proteger documentos con marcas de agua para compartir de forma segura.';

  @override
  String authorLabel(String name) {
    return 'Autor: $name';
  }

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String get checkingForUpdates => 'Buscando actualizaciones...';

  @override
  String get upToDate => 'Estás usando la última versión.';

  @override
  String updateAvailable(String version) {
    return '¡Una nueva versión ($version) está disponible!';
  }

  @override
  String get updateCheckError => 'No se pudo verificar las actualizaciones.';

  @override
  String get githubRepository => 'Repositorio de GitHub';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get viewUpdate => 'Ver';

  @override
  String get analyzeFile => 'Analizar archivo (LSB)';

  @override
  String get fileAnalyzerTitle => 'Analizador de archivos (LSB)';

  @override
  String get fileAnalyzerDescription =>
      'Selecciona un archivo para buscar firmas de SecureMark ocultas.';

  @override
  String get pickAndAnalyze => 'Elegir y analizar';

  @override
  String encryptedFileDetected(String name) {
    return '🔐 Archivo cifrado detectado: $name. Por favor proporciona la contraseña correcta.';
  }

  @override
  String hiddenFileDetected(String name, String size) {
    return '📁 Archivo oculto detectado: $name ($size)';
  }

  @override
  String get encryptedSignatureDetected =>
      '🔐 Firma cifrada detectada. Por favor proporciona la contraseña correcta.';

  @override
  String signatureFound(String message) {
    return '✅ Firma encontrada: \"$message\"';
  }

  @override
  String robustSignatureFound(String message) {
    return '💪 Firma robusta encontrada: \"$message\"';
  }

  @override
  String get noSignatureFound =>
      '❌ No se detectó ninguna firma de SecureMark en este archivo.';

  @override
  String analysisError(String error) {
    return 'Error durante el análisis: $error';
  }

  @override
  String get analysisResult => 'Resultado:';

  @override
  String get steganographyVerified => 'Esteganografía verificada';

  @override
  String get steganographyVerificationFailed =>
      'Verificación de esteganografía fallida';

  @override
  String get steganographyEnabledHint =>
      'La esteganografía está habilitada y será aplicada';

  @override
  String get hideFileWithSteganographyTitle =>
      'Ocultar un archivo (experimental)';

  @override
  String get hideFileWithSteganographySubtitle =>
      'Incluye un archivo entero dentro de la imagen (podría aumentar el tamaño de salida)';

  @override
  String get hideFileEnabledHint => 'Se incluirá un archivo oculto';

  @override
  String get selectFileToHide => 'Seleccionar archivo para ocultar';

  @override
  String selectedHiddenFile(String name) {
    return 'Archivo oculto: $name';
  }

  @override
  String get hiddenFileSecurityWarning =>
      'Nota de seguridad: los archivos ocultos solo son seguros si se cifran antes de incluir. La esteganografía oscurece pero no cifra tus datos.';

  @override
  String get steganographyPasswordLabel => 'Contraseña de cifrado';

  @override
  String get steganographyPasswordHint =>
      'Ingresa la contraseña para proteger el archivo oculto';

  @override
  String get steganographyPasswordNote =>
      'Nota: esta contraseña será necesaria para extraer el archivo oculto usando SecureMark. Usa cifrado AES-256.';

  @override
  String get steganographyZipNote =>
      'Importante: si usa esteganografía y comparte estos archivos a través de WhatsApp, Signal u otras aplicaciones que comprimen imágenes, debe habilitar la compresión ZIP o comprimerlos manualmente. El intercambio directo suele destruir la esteganografía invisible.';

  @override
  String get steganographyImageOnlyNote =>
      'Nota: La esteganografía (firmas invisibles y archivos ocultos) solo es compatible con archivos de imagen (JPG, PNG, WebP). Se omitirá para archivos PDF.';

  @override
  String get steganographyTextLabel => 'Firma esteganográfica personalizada';

  @override
  String get steganographyTextHint =>
      'Ingrese el texto personalizado para ocultar (por defecto es el texto de la marca de agua si está vacío)';

  @override
  String get zipAllFiles => 'ZIP todos los archivos';

  @override
  String get zipEnabledHint =>
      'Compresión ZIP habilitada para compartir. NOTA: las aplicaciones de terceros (WhatsApp, Signal, etc.) comprimen las imágenes, lo que puede destruir las firmas de esteganografía. Habilite ZIP para evitar la pérdida de firmas.';

  @override
  String get zipDisabledHint => 'Compresión ZIP deshabilitada';

  @override
  String get qrWatermarkTitle => 'Marca de agua de código QR';

  @override
  String get enableQrWatermark => 'Habilitar código QR';

  @override
  String get enableQrWatermarkSubtitle => 'Incluye metadatos en un código QR';

  @override
  String get qrMode => 'Modo de código QR';

  @override
  String get qrVisibleMode => 'Código QR visible';

  @override
  String get qrVisibleModeDesc => 'Muestra código QR en la imagen';

  @override
  String get qrAuthorLabel => 'Nombre del autor';

  @override
  String get qrAuthorHint => 'ej. Juan Pérez';

  @override
  String get qrUrlLabel => 'URL o sitio web';

  @override
  String get qrUrlHint => 'ej. https://ejemplo.com';

  @override
  String get qrVisibleOptions => 'Opciones de QR visible';

  @override
  String get qrPositionLabel => 'Ubicación de código QR';

  @override
  String get qrPosTopLeft => 'Arriba izquierda';

  @override
  String get qrPosTopRight => 'Arriba derecha';

  @override
  String get qrPosBottomLeft => 'Abajo izquierda';

  @override
  String get qrPosBottomRight => 'Abajo derecha';

  @override
  String get qrPosCenter => 'Centro';

  @override
  String qrSizeValue(int value) {
    return 'Tamaño del código QR: ${value}px';
  }

  @override
  String qrOpacityValue(int value) {
    return 'Opacidad del código QR: $value%';
  }

  @override
  String receivedFilesFromSharing(int count) {
    return '📥 Recibido $count archivo(s) del compartir';
  }

  @override
  String get unsupportedSharedFormat =>
      '⚠️ Archivos compartidos no están en un formato compatible (JPG, PNG, WebP, PDF, HEIC/HEIF)';

  @override
  String get signatureCopied => 'Firma copiada al portapapeles';

  @override
  String get copySignature => 'Copiar firma';

  @override
  String get saveHiddenFile => 'Guardar archivo oculto';

  @override
  String fileSaved(String name) {
    return 'Archivo guardado: $name';
  }

  @override
  String errorSavingFile(String error) {
    return 'Error al guardar archivo: $error';
  }

  @override
  String antiAiProtectionValue(int value) {
    return 'Protección de eliminación anti-IA: $value%';
  }

  @override
  String get antiAiProtectionNote =>
      'Nota: añade ruido y ruido para hacer la marca de agua mucho más difícil de eliminar con IA. Los niveles más altos tardan más.';

  @override
  String get antiAiEnabledHint =>
      'La protección de eliminación anti-IA está habilitada';

  @override
  String get aiCloakingTitle => 'Cloaking de IA (Adversarial)';

  @override
  String get aiCloakingSubtitle =>
      'Inyecta ruido adversario invisible para interrumpir el entrenamiento de IA y robo de estilo.';

  @override
  String get aiCloakingEnabledHint => 'El cloaking de IA está activo';

  @override
  String get qrContentType => 'Tipo de contenido QR';

  @override
  String get qrTypeMetadata => 'Metadatos (JSON)';

  @override
  String get qrTypeUrl => 'Redirección de sitio web';

  @override
  String get qrTypeVCard => 'Contacto (vCard)';

  @override
  String get vCardFirstName => 'Nombre';

  @override
  String get vCardLastName => 'Apellido';

  @override
  String get vCardPhone => 'Número de teléfono';

  @override
  String get vCardEmail => 'Dirección de correo electrónico';

  @override
  String get vCardOrg => 'Organización';

  @override
  String get invalidUrlError =>
      'Por favor, ingresa una URL válida (ej. https://ejemplo.com)';

  @override
  String get noQrFound => '❌ No se detectó ningún código QR';

  @override
  String get abToggleTooltipOriginal => 'Mostrar original';

  @override
  String get abToggleTooltipProcessed => 'Mostrar procesado';

  @override
  String get processingCancelled => 'Procesamiento cancelado';

  @override
  String processingStatusMultiple(int successCount, int failedCount) {
    return 'Procesado $successCount archivos con éxito. $failedCount archivos fallaron.';
  }

  @override
  String get processingFailedSingle =>
      'No se pudo procesar el archivo. Por favor verifica el formato del archivo e inténtalo de nuevo.';

  @override
  String processingFailedMultiple(int count) {
    return 'No se pudo procesar $count archivos. Por favor verifica los formatos de archivos e inténtalo de nuevo.';
  }

  @override
  String fileSavedTo(String path) {
    return 'Archivo guardado en: $path';
  }

  @override
  String get saveFailedGeneral =>
      'No se pudo guardar los archivos. Por favor verifica los permisos y el espacio de almacenamiento.';

  @override
  String saveStatusMultiple(int successCount, int failedCount) {
    return 'Guardado $successCount archivos. $failedCount archivos fallaron.';
  }

  @override
  String get filesSavedTitle => 'Archivos guardados';

  @override
  String get processingErrorsTitle => 'Errores de procesamiento';

  @override
  String successfullySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos guardados con éxito',
      one: '1 archivo guardado con éxito',
    );
    return '$_temp0:';
  }

  @override
  String failedSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
    );
    return 'No se pudo guardar $_temp0:';
  }

  @override
  String willSaveAsIn(String name, String path) {
    return 'Se guardará como: $name en $path/';
  }

  @override
  String willSaveMultipleIn(int count, String path) {
    return 'Se guardarán $count archivos en: $path/';
  }

  @override
  String get savingFiles => 'Guardando archivos...';

  @override
  String errorSavingFiles(String error) {
    return 'Error al guardar archivos: $error';
  }

  @override
  String get foregroundTaskTitle => 'Procesamiento de SecureMark';

  @override
  String get foregroundTaskDescription =>
      'Mostrando progreso de marcado de documentos';

  @override
  String foregroundTaskUpdate(int current, int total, String name) {
    return 'Procesando archivo $current de $total: $name';
  }

  @override
  String get fileTooLargeTitle => 'Archivo demasiado grande';

  @override
  String fileTooLargeMessage(String fileName, String fileSize,
      String imageDimensions, String maxCapacity) {
    return 'El archivo \"$fileName\" ($fileSize KB) es demasiado grande para ocultar en esta imagen ($imageDimensions).\n\nCapacidad máxima: $maxCapacity KB\n\nPor favor usa una imagen más grande o comprime/reduce el tamaño del archivo.';
  }

  @override
  String get loadingSelectedFiles => 'Cargando archivos seleccionados...';

  @override
  String get profileLabel => 'Perfil';

  @override
  String get profileDescription => 'Ajustes rápidos para casos de uso comunes';

  @override
  String get profileNone => 'Personalizado';

  @override
  String get profileSecureIdentity => 'Identidad';

  @override
  String get profileOnlineImage => 'Imagen';

  @override
  String get profileQrCode => 'Código QR';

  @override
  String get profileShareDocument => 'Doc';

  @override
  String get progressValidating => 'Validando archivo...';

  @override
  String get progressFromCache => 'Obtenido de la caché';

  @override
  String get progressDetectingType => 'Detectando tipo de archivo...';

  @override
  String get progressStarting => 'Iniciando procesamiento...';

  @override
  String get progressComplete => 'Procesamiento completado';

  @override
  String get progressReadingImage => 'Leyendo archivo de imagen...';

  @override
  String get progressRenderingFont => 'Renderizando fuente...';

  @override
  String get progressFinalizingImage => 'Finalizando imagen...';

  @override
  String get progressVerifyingStegano => 'Verificando esteganografía...';

  @override
  String get progressSteganoVerified => 'Esteganografía verificada';

  @override
  String get progressSteganoFailed => 'Verificación de esteganografía fallida';

  @override
  String get progressRasterizing => 'Rasterizando PDF (aplanando)...';

  @override
  String get progressReadingPdf => 'Leyendo archivo PDF...';

  @override
  String get progressAddingLayer => 'Añadiendo capa de marca de agua...';

  @override
  String get progressFinalizingPdf => 'Finalizando PDF...';

  @override
  String get progressParsingPdf => 'Analizando documento PDF...';

  @override
  String get progressDecodingImage => 'Decodificando imagen...';

  @override
  String get progressResizingImage => 'Redimensionando imagen...';

  @override
  String get progressApplyingCloaking => 'Aplicando cloaking adversarial IA...';

  @override
  String get progressApplyingWatermark => 'Aplicando marca de agua...';

  @override
  String get progressEmbeddingRobust =>
      'Incluyendo marca de agua robusta (DCT)...';

  @override
  String get progressHidingFile =>
      'Ocultando archivo en imagen (esteganografía)...';

  @override
  String get progressEmbeddingLsb => 'Incluyendo firma invisible (LSB)...';

  @override
  String get progressEncodingImage => 'Codificando imagen...';

  @override
  String get progressGeneratingQr => 'Generando código QR...';

  @override
  String get progressEmbeddingQr => 'Incluyendo código QR...';

  @override
  String get progressQrEmbedded => 'Código QR incluido';

  @override
  String progressWatermarkingPage(int current, int total) {
    return 'Marcando página $current/$total...';
  }

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeSystem => 'Predeterminado del sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeAmoled => 'Negro Amoled';

  @override
  String get resetProfiles => 'Reiniciar perfiles';

  @override
  String resetProfileConfirm(String profile) {
    return '¿Reiniciar $profile a los valores de fábrica?';
  }

  @override
  String profileSaved(String profile) {
    return 'Configuración actual guardada por defecto para $profile';
  }

  @override
  String profileReset(String profile) {
    return 'Perfil $profile reiniciado a los valores de fábrica';
  }

  @override
  String get previewModeOriginal => 'Original';

  @override
  String get previewModeProcessed => 'Procesado';

  @override
  String get previewModeHeatmap => 'Mapa de calor de manipulación';

  @override
  String get authenticityVerified => 'AUTENTICIDAD VERIFICADA';

  @override
  String get fullAuthenticityConfirmed => 'AUTENTICIDAD TOTAL CONFIRMADA';

  @override
  String get partialAuthenticity => 'AUTENTICIDAD PARCIAL';

  @override
  String get tamperingDetected => 'MANIPULACIÓN DETECTADA';

  @override
  String get forensicLayerContent => 'Contenido (Imagen + Datos ocultos)';

  @override
  String get forensicLayerSource => 'Fuente (Imagen visible)';

  @override
  String get forensicStatusValid => 'VÁLIDO';

  @override
  String get forensicStatusModified => 'MODIFICADO';

  @override
  String get verifFullIntegrity =>
      'Integridad total confirmada (Imagen + Datos ocultos).';

  @override
  String get verifPartialIntegrity =>
      'Integridad visual confirmada, pero la esteganografía oculta ha sido modificada o dañada.';

  @override
  String get verifTamperingDetected =>
      'Error en la comprobación forense. Tanto los píxeles visuales como los datos ocultos parecen modificados.';

  @override
  String get onboardingPage1Title => 'Protege tus documentos';

  @override
  String get onboardingPage1Body =>
      'Marcas de agua visibles e invisibles para compartir con seguridad.';

  @override
  String get onboardingPage2Title => 'Estenografía';

  @override
  String get onboardingPage2Body =>
      'Incrusta firmas ocultas o archivos completos dentro de imágenes.';

  @override
  String get onboardingPage3Title => 'Protección IA';

  @override
  String get onboardingPage3Body =>
      'Protección Anti-IA y Cloaking para frustrar modelos de IA.';

  @override
  String get onboardingStepTitle => 'Cómo funciona';

  @override
  String get onboardingStep1 =>
      '1. Elige un perfil preestablecido para tu caso.';

  @override
  String get onboardingStep2 => '2. Importa tus imágenes o archivos PDF.';

  @override
  String get onboardingStep2NoCamera => '2. Elige tus imágenes o archivos PDF.';

  @override
  String get onboardingStep3 =>
      '3. Haz clic en Aplicar para generar las marcas de agua.';

  @override
  String get onboardingStep4 => '4. Comparte o guarda los resultados.';

  @override
  String get onboardingExpertTitle => 'Perfiles y Opciones';

  @override
  String get onboardingExpertModeTitle => 'Modo Experto';

  @override
  String get onboardingSaveProfileTitle => 'Guardar Ajustes';

  @override
  String get onboardingLiveStatusTitle => 'Estado de Seguridad';

  @override
  String get onboardingFileAnalyzerTitle => 'Verificación';

  @override
  String get onboardingProfileSave =>
      'Mantén presionado un perfil para guardar la configuración actual como predeterminada.';

  @override
  String get onboardingExpertNote =>
      'El modo experto (arriba a la derecha) desbloquea ajustes avanzados';

  @override
  String get onboardingOptionsNote =>
      'Mira qué opciones están activas (doble toque para configurar)';

  @override
  String get onboardingFileAnalyzerNote =>
      'Analizador de archivos para buscar firmas o archivos ocultos';

  @override
  String get onboardingQrCodeNote =>
      'Incrusta contacto, enlaces o metadatos mediante código QR.';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingDone => 'Entendido';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get showGuide => 'Ver guía';
}
