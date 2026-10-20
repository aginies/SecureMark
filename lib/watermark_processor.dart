import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show TextPainter, TextSpan, TextAlign, TextDirection, FontWeight;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync;

import 'font_manager.dart';
import 'qr_config.dart';
import 'watermark_error.dart';
import 'models/processor_models.dart';
import 'steganography/lsb_handler.dart';
import 'steganography/dct_handler.dart';
import 'steganography/forensic_utils.dart';
import 'steganography/encryption_utils.dart';
import 'utils/color_utils.dart';
import 'utils/identity_manager.dart';
import 'utils/watermark_utils.dart';
import 'utils/image_utils.dart';
import 'utils/watermark_field_handler.dart';
import 'package:crypto/crypto.dart';

/// Every input that can change the bytes of a processed document.
///
/// The result cache hashes this record directly: Dart records derive `==` and
/// `hashCode` from all of their fields, so any field declared here takes part
/// in the cache key automatically. There is no second, hand-maintained list of
/// hashed terms for a setting to go missing from — and because a record literal
/// with fewer named fields is not assignable to this type, a call site that
/// forgets to supply a setting fails to compile instead of silently caching a
/// result that ignores it.
///
/// This is the structural guard for the `forcePng` defect, where the field was
/// declared and passed at the call site but never hashed.
typedef WatermarkCacheInput = ({
  String filePath,
  double transparency,
  double density,
  String watermarkText,
  bool useRandomColor,
  int selectedColorValue,
  double fontSize,
  String fontFamily,
  int jpegQuality,
  int? targetSize,
  bool forcePng,
  bool includeTimestamp,
  bool preserveMetadata,
  bool rasterizePdf,
  String filePrefix,
  double antiAiLevel,
  bool useSteganography,
  bool useRobustSteganography,
  bool useAiCloaking,
  WatermarkType watermarkType,
  int? watermarkImageLength,
  String? steganographyPassword,
  String? steganographyText,
  String? hiddenFileName,
  int? hiddenFileLength,
  bool? visibleQr,
  bool? enablePdfSecurity,
  String? pdfUserPassword,
  String? pdfOwnerPassword,
  bool? pdfAllowPrinting,
  bool? pdfAllowCopying,
  bool? pdfAllowEditing,
  bool? digitallySign,

  /// Base64 of the signing key pair's public half, null when the run does not
  /// sign. Identifies the identity embedded in the output, so cached results
  /// cannot outlive the key that produced them.
  String? signerPublicKey,
});

class WatermarkProcessor {
  static final Map<String, ProcessResult> _resultCache = {};
  static const int _maxCacheSize = 10;

  // Resolution limits to prevent memory exhaustion
  // 50MP = ~200MB RGB (600MB with processing overhead)
  static const int _maxMegapixels = 50;
  static const int _maxPixelCount = _maxMegapixels * 1000000;

  static void clearCache() => _resultCache.clear();

  /// Derives the result-cache key from [input].
  ///
  /// Adding a setting means adding a field to [WatermarkCacheInput] and passing
  /// it here — never adding a term to a hash list, since the record's own
  /// `hashCode` already covers every field it holds.
  static String _generateCacheKey(WatermarkCacheInput input) =>
      input.hashCode.toRadixString(36); // Base-36 for a compact key

  static Future<bool> isSupportedFile(File file) =>
      WatermarkUtils.isSupportedFile(file);

  static Future<ProcessResult> processFile({
    required File file,
    // On web the browser has no filesystem, so the caller passes the input
    // bytes in memory; on native this stays null and the file is read from
    // disk as usual.
    Uint8List? inputBytes,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    WatermarkFont font = WatermarkFont.arial,
    int jpegQuality = 75,
    int? targetSize,
    bool forcePng = false,
    bool includeTimestamp = false,
    bool preserveMetadata = false,
    bool rasterizePdf = false,
    String filePrefix = 'securemark-',
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    bool digitallySign = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    Uint8List? signingPrivateKey,
    Uint8List? signingPublicKey,
    bool enablePdfSecurity = false,
    String? pdfUserPassword,
    String? pdfOwnerPassword,
    bool pdfAllowPrinting = false,
    bool pdfAllowCopying = false,
    bool pdfAllowEditing = false,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    if (cancellationToken?.isCancelled == true) {
      throw const WatermarkError(
          type: WatermarkErrorType.operationCancelled, message: 'Cancelled');
    }

    if ((useSteganography || useRobustSteganography) &&
        (steganographyText == null || steganographyText.isEmpty)) {
      throw const WatermarkError(
        type: WatermarkErrorType.missingSteganographySignature,
        message: 'missingSteganographySignature',
      );
    }

    if (qrConfig != null && !qrConfig.isValid) {
      throw const WatermarkError(
        type: WatermarkErrorType.missingQrContent,
        message: 'missingQrContent',
      );
    }

    onProgress?.call(0.0, 'progressValidating');
    String type;
    try {
      final inputSize = inputBytes?.length ?? await file.length();
      if (inputSize > 100 * 1024 * 1024) {
        throw WatermarkError(
            type: WatermarkErrorType.fileTooLarge,
            message: 'File too large',
            filePath: file.path);
      }
      type = await WatermarkUtils.detectFileType(file);
      final supported = [
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.pdf',
        '.heic',
        '.heif'
      ];
      if (!supported.contains(type)) {
        throw WatermarkError(
            type: WatermarkErrorType.unsupportedFileType,
            message: 'Unsupported file type: $type',
            filePath: file.path);
      }
    } catch (e) {
      if (e is WatermarkError) rethrow;
      throw WatermarkError(
          type: WatermarkErrorType.fileNotFound,
          message: 'File not found or unreadable',
          filePath: file.path,
          originalError: e);
    }

    // The signing identity must be resolved BEFORE the cache lookup, not after
    // it: a signed output embeds a signature made by this device's key, so the
    // key is part of what makes a cached result valid. Keying on the public key
    // means an identity switch or reset can never serve a stale signature back
    // out of the cache. These locals intentionally override the identically
    // named parameters, which are ignored: signing always uses the device
    // identity.
    Uint8List? signingPrivateKey;
    Uint8List? signingPublicKey;
    if (digitallySign) {
      signingPrivateKey = await IdentityManager.getDevicePrivateKey();
      signingPublicKey = await IdentityManager.getDevicePublicKeyBytes();
    }

    // Record literal: every field of [WatermarkCacheInput] must be supplied
    // here, so a newly added setting cannot be omitted from the cache key.
    final cacheKey = _generateCacheKey((
      filePath: file.path,
      transparency: transparency,
      density: density,
      watermarkText: watermarkText,
      useRandomColor: useRandomColor,
      selectedColorValue: selectedColorValue,
      fontSize: fontSize,
      fontFamily: font.fontFamily,
      jpegQuality: jpegQuality,
      targetSize: targetSize,
      forcePng: forcePng,
      includeTimestamp: includeTimestamp,
      preserveMetadata: preserveMetadata,
      rasterizePdf: rasterizePdf,
      filePrefix: filePrefix,
      antiAiLevel: antiAiLevel,
      useSteganography: useSteganography,
      useRobustSteganography: useRobustSteganography,
      useAiCloaking: useAiCloaking,
      watermarkType: watermarkType,
      watermarkImageLength: watermarkImageBytes?.length,
      steganographyPassword: steganographyPassword,
      steganographyText: steganographyText,
      hiddenFileName: hiddenFileName,
      hiddenFileLength: hiddenFileBytes?.length,
      visibleQr: qrConfig?.visibleQr,
      enablePdfSecurity: enablePdfSecurity,
      pdfUserPassword: pdfUserPassword,
      pdfOwnerPassword: pdfOwnerPassword,
      pdfAllowPrinting: pdfAllowPrinting,
      pdfAllowCopying: pdfAllowCopying,
      pdfAllowEditing: pdfAllowEditing,
      digitallySign: digitallySign,
      // Null when the run does not sign; the signing key pair is folded into
      // the key whenever a signature will be embedded in the output.
      signerPublicKey:
          signingPublicKey == null ? null : base64Encode(signingPublicKey),
    ));
    if (_resultCache.containsKey(cacheKey)) {
      onProgress?.call(1.0, 'progressFromCache');
      return _resultCache[cacheKey]!;
    }

    // The visible watermark always carries a date/time stamp; the
    // includeTimestamp flag only gates the timestamp in the output filename
    // (see WatermarkUtils.outputPath).
    final resolvedText = WatermarkUtils.resolvedWatermarkText(watermarkText);
    ProcessResult result;

    if (type == '.pdf') {
      result = await _processPdf(
          file: file,
          inputBytes: inputBytes,
          transparency: transparency,
          density: density,
          watermarkText: resolvedText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          font: font,
          jpegQuality: jpegQuality,
          forcePng: forcePng,
          includeTimestamp: includeTimestamp,
          preserveMetadata: preserveMetadata,
          rasterizePdf: rasterizePdf,
          filePrefix: filePrefix,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          useAiCloaking: useAiCloaking,
          digitallySign: digitallySign,
          signingPrivateKey: signingPrivateKey,
          signingPublicKey: signingPublicKey,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          steganographyPassword: steganographyPassword,
          steganographyText: steganographyText,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          enablePdfSecurity: enablePdfSecurity,
          pdfUserPassword: pdfUserPassword,
          pdfOwnerPassword: pdfOwnerPassword,
          pdfAllowPrinting: pdfAllowPrinting,
          pdfAllowCopying: pdfAllowCopying,
          pdfAllowEditing: pdfAllowEditing,
          onProgress: (p, m) => onProgress?.call(0.1 + (p * 0.8), m),
          cancellationToken: cancellationToken);
    } else {
      result = await _processImage(
          file: file,
          inputBytes: inputBytes,
          transparency: transparency,
          density: density,
          watermarkText: resolvedText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          font: font,
          jpegQuality: jpegQuality,
          targetSize: targetSize,
          forcePng: forcePng,
          includeTimestamp: includeTimestamp,
          preserveMetadata: preserveMetadata,
          filePrefix: filePrefix,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          useAiCloaking: useAiCloaking,
          digitallySign: digitallySign,
          signingPrivateKey: signingPrivateKey,
          signingPublicKey: signingPublicKey,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          steganographyPassword: steganographyPassword,
          steganographyText: steganographyText,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          onProgress: (p, m) => onProgress?.call(0.1 + (p * 0.8), m),
          cancellationToken: cancellationToken);
    }
    _addToCache(cacheKey, result);
    return result;
  }

  static void _addToCache(String key, ProcessResult result) {
    if (_resultCache.length >= _maxCacheSize) {
      _resultCache.remove(_resultCache.keys.first);
    }
    _resultCache[key] = result;
  }

  static Future<ProcessResult> _processImage({
    required File file,
    Uint8List? inputBytes,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    required WatermarkFont font,
    required int jpegQuality,
    int? targetSize,
    bool forcePng = false,
    bool includeTimestamp = false,
    bool preserveMetadata = false,
    String filePrefix = 'securemark-',
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    bool digitallySign = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    Uint8List? signingPrivateKey,
    Uint8List? signingPublicKey,
    bool enablePdfSecurity = false,
    String? pdfUserPassword,
    String? pdfOwnerPassword,
    bool pdfAllowPrinting = false,
    bool pdfAllowCopying = false,
    bool pdfAllowEditing = false,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final bytes = inputBytes ?? await file.readAsBytes();
    final extension = await WatermarkUtils.detectFileType(file);

    // Pre-render TTF stamps if using non-bitmap fonts (must be done in main thread)
    Map<String, Uint8List>? preRenderedStamps;
    if (watermarkType == WatermarkType.text && !font.isBitmap) {
      onProgress?.call(0.1, 'progressRenderingFont');
      final stampKey = '${font.fontFamily}-${fontSize.round()}';
      try {
        final stampBytes = await _renderTextWithFlutterCanvas(
          text: watermarkText,
          font: font,
          fontSize: fontSize.round(),
          color: const ui.Color.fromARGB(
              255, 255, 255, 255), // White base, will be colorized
        );
        preRenderedStamps = {stampKey: stampBytes};
      } catch (_) {
        // Silently fail or ignore error
      }
    }

    try {
      final completer = Completer<Map<String, dynamic>>();
      ReceivePort? receivePort;

      // Message protocol shared by both execution modes (see
      // _runImagePipeline): log, progress, result, error.
      void handleMessage(dynamic message) {
        if (message is Map) {
          if (message.containsKey('log')) {
            // Forward log from isolate
            onProgress?.call(-1.0, message['log'] as String);
          } else if (message.containsKey('progress') &&
              message.containsKey('message')) {
            // Progress update
            onProgress?.call(
                message['progress'] as double, message['message'] as String);
          } else if (message.containsKey('result')) {
            // Final result - unwrap TransferableTypedData
            final transferableResult =
                message['result'] as Map<String, dynamic>;
            final result = transferableResult.map((key, value) {
              if (value is TransferableTypedData) {
                return MapEntry(key, value.materialize().asUint8List());
              }
              return MapEntry(key, value);
            });
            completer.complete(result);
            receivePort?.close();
          } else if (message.containsKey('error')) {
            // Error occurred
            completer.completeError(message['error']);
            receivePort?.close();
          }
        }
      }

      // Optimize: Use TransferableTypedData to avoid copying large byte arrays (200-500ms faster)
      // Zero-copy transfer on native; plain lists on web (no isolates there)
      final params = <String, dynamic>{
        'inputBytes': kIsWeb ? bytes : TransferableTypedData.fromList([bytes]),
        'transparency': transparency,
        'density': density,
        'watermarkText': watermarkText,
        'useRandomColor': useRandomColor,
        'selectedColorValue': selectedColorValue,
        'fontSize': fontSize,
        'font': font,
        'jpegQuality': jpegQuality,
        'targetSize': targetSize,
        'forcePng': forcePng,
        'filePath': file.path,
        'originalExtension': extension,
        'preserveMetadata': preserveMetadata,
        'antiAiLevel': antiAiLevel,
        'useSteganography': useSteganography,
        'useRobustSteganography': useRobustSteganography,
        'useAiCloaking': useAiCloaking,
        'digitallySign': digitallySign,
        'watermarkType': watermarkType,
        'watermarkImageBytes': watermarkImageBytes != null
            ? (kIsWeb
                ? watermarkImageBytes
                : TransferableTypedData.fromList([watermarkImageBytes]))
            : null,
        'steganographyPassword': steganographyPassword,
        'steganographyText': steganographyText,
        'hiddenFileName': hiddenFileName,
        'hiddenFileBytes': hiddenFileBytes != null
            ? (kIsWeb
                ? hiddenFileBytes
                : TransferableTypedData.fromList([hiddenFileBytes]))
            : null,
        'qrConfig': qrConfig,
        'signingPrivateKey': signingPrivateKey != null
            ? (kIsWeb
                ? signingPrivateKey
                : TransferableTypedData.fromList([signingPrivateKey]))
            : null,
        'signingPublicKey': signingPublicKey,
        'preRenderedStamps': kIsWeb
            ? preRenderedStamps
            : preRenderedStamps?.map((key, value) =>
                MapEntry(key, TransferableTypedData.fromList([value]))),
        'enablePdfSecurity': enablePdfSecurity,
        'pdfUserPassword': pdfUserPassword,
        'pdfOwnerPassword': pdfOwnerPassword,
        'pdfAllowPrinting': pdfAllowPrinting,
        'pdfAllowCopying': pdfAllowCopying,
        'pdfAllowEditing': pdfAllowEditing,
      };

      if (kIsWeb) {
        // The web engine has no isolates (SendPort/ReceivePort throw
        // UnsupportedError) — run the same pipeline on the main isolate.
        // Yielding to the event loop between steps keeps the progress UI
        // alive while it runs.
        await _runImagePipeline(params, (message) async {
          handleMessage(message);
          await Future<void>.delayed(Duration.zero);
        });
      } else {
        // Create ReceivePort to get progress updates from isolate
        receivePort = ReceivePort();
        receivePort.listen(handleMessage);
        await Isolate.spawn(
            _imageIsolateEntry, {'sendPort': receivePort.sendPort, ...params});
      }

      final rawRes = await completer.future;
      final Map<String, dynamic> res = (rawRes as Map).map((key, value) {
        if (value is TransferableTypedData) {
          return MapEntry(key as String, value.materialize().asUint8List());
        }
        return MapEntry(key as String, value);
      });

      final bool shouldForcePng = forcePng || digitallySign;
      String outExt =
          (extension == '.heic' || extension == '.heif') ? '.jpg' : extension;
      if (shouldForcePng) outExt = '.png';

      final outPath = WatermarkUtils.outputPath(
          file.path, outExt, includeTimestamp, filePrefix);

      // Verify steganography if enabled
      bool verified = false;
      bool robustVerified = false;
      if (useSteganography ||
          useRobustSteganography ||
          digitallySign ||
          hiddenFileName != null) {
        onProgress?.call(0.9, 'progressVerifyingStegano');

        final analysis =
            await analyzeImage(res['output']!, password: steganographyPassword);
        final expected = (steganographyText?.isNotEmpty == true)
            ? steganographyText!
            : watermarkText;

        if (useSteganography || hiddenFileName != null || digitallySign) {
          verified = (hiddenFileName == null ||
                  (analysis.file != null &&
                      analysis.file!.fileName == hiddenFileName)) &&
              (!useSteganography ||
                  (analysis.signature?.startsWith(expected) ?? false)) &&
              (!digitallySign || analysis.integrityVerified);
        }

        if (useRobustSteganography) {
          robustVerified =
              analysis.robustSignature?.startsWith(expected) ?? false;
        }

        if (verified || robustVerified) {
          onProgress?.call(0.95, 'progressSteganoVerified');
        } else {
          onProgress?.call(0.95, 'progressSteganoFailed');
        }
      }

      onProgress?.call(1.0, 'progressComplete');

      final List<String> applied = [];
      if (useSteganography) applied.add('steganographyTitle');
      if (useRobustSteganography) applied.add('robustSteganographyTitle');
      if (digitallySign) applied.add('digitallySignTitle');
      if (useAiCloaking) applied.add('aiCloakingTitle');
      if (antiAiLevel > 0) applied.add('antiAiProtectionTitle');
      if (qrConfig != null) applied.add('qrWatermarkTitle');
      if (forcePng) applied.add('forcePngTitle');
      if (targetSize != null) applied.add('imageResizingTitle');
      if (preserveMetadata) applied.add('preserveMetadata');

      return ProcessResult(
          outputPath: outPath,
          outputBytes: res['output']!,
          previewBytes: res['output']!,
          originalBytes: bytes,
          heatmapBytes: res['heatmap'],
          steganographyVerified: verified,
          robustVerified: robustVerified,
          width: res['width'] as int?,
          height: res['height'] as int?,
          appliedFeatures: applied);
    } catch (e) {
      if (e is WatermarkError) {
        rethrow;
      }
      throw WatermarkError(
          type: WatermarkErrorType.invalidImageData,
          message: 'Image process fail',
          filePath: file.path,
          originalError: e);
    }
  }

  // Isolate entry point for image processing with progress reporting
  /// Unwraps a byte-array pipeline parameter.
  ///
  /// Native isolates receive zero-copy [TransferableTypedData]; the web
  /// engine has no isolates (and no TransferableTypedData), so on web the
  /// same parameters arrive as plain [Uint8List].
  static Uint8List? _bytesFromParam(dynamic value) {
    if (value == null) return null;
    if (value is TransferableTypedData) {
      return value.materialize().asUint8List();
    }
    return value as Uint8List;
  }

  /// Runs the image pipeline, reporting through [send] with the message
  /// protocol {'log'}, {'progress','message'}, {'result'} or {'error'}.
  ///
  /// On native this body runs inside a spawned isolate; on web the engine
  /// has no isolates at all, so the same code runs on the main isolate.
  static Future<void> _runImagePipeline(Map<String, dynamic> params,
      FutureOr<void> Function(Map<String, dynamic>) send) async {
    IdentityManager.onLog = (msg) => send({'log': msg});

    try {
      // Unwrap TransferableTypedData (native) or take the plain list (web)
      final inputBytes = _bytesFromParam(params['inputBytes'])!;
      final watermarkImageBytes =
          _bytesFromParam(params['watermarkImageBytes']);
      final hiddenFileBytes = _bytesFromParam(params['hiddenFileBytes']);
      final preRenderedStamps = params['preRenderedStamps'] != null
          ? (params['preRenderedStamps'] as Map<String, dynamic>)
              .map((key, value) => MapEntry(key, _bytesFromParam(value)!))
          : null;

      final signingPrivateKey = _bytesFromParam(params['signingPrivateKey']);
      final signingPublicKey = params['signingPublicKey'] as Uint8List?;

      if (signingPrivateKey != null && signingPublicKey != null) {
        IdentityManager.initFromKeys(signingPrivateKey, signingPublicKey);
      }

      final result = await _renderWatermarkedImageBytes(
        inputBytes: inputBytes,
        transparency: params['transparency'] as double,
        density: params['density'] as double,
        watermarkText: params['watermarkText'] as String,
        useRandomColor: params['useRandomColor'] as bool,
        selectedColorValue: params['selectedColorValue'] as int,
        fontSize: params['fontSize'] as double,
        font: params['font'] as WatermarkFont,
        jpegQuality: params['jpegQuality'] as int,
        targetSize: params['targetSize'] as int?,
        forcePng: params['forcePng'] as bool? ?? false,
        filePath: params['filePath'] as String,
        originalExtension: params['originalExtension'] as String,
        preserveMetadata: params['preserveMetadata'] as bool,
        antiAiLevel: params['antiAiLevel'] as double,
        useSteganography: params['useSteganography'] as bool,
        useRobustSteganography: params['useRobustSteganography'] as bool,
        useAiCloaking: params['useAiCloaking'] as bool,
        digitallySign: params['digitallySign'] as bool,
        watermarkType: params['watermarkType'] as WatermarkType,
        watermarkImageBytes: watermarkImageBytes,
        steganographyPassword: params['steganographyPassword'] as String?,
        steganographyText: params['steganographyText'] as String?,
        hiddenFileName: params['hiddenFileName'] as String?,
        hiddenFileBytes: hiddenFileBytes,
        qrConfig: params['qrConfig'] as QrWatermarkConfig?,
        preRenderedStamps: preRenderedStamps,
        sendProgress: send,
      );

      // Wrap Uint8List in TransferableTypedData for faster transfer back
      // (native only — the web engine has no TransferableTypedData)
      final transferableResult = kIsWeb
          ? result
          : result.map((key, value) {
              if (value is Uint8List) {
                return MapEntry(key, TransferableTypedData.fromList([value]));
              }
              return MapEntry(key, value);
            });
      send({'result': transferableResult});
    } catch (e) {
      send({'error': e});
    }
  }

  static void _imageIsolateEntry(Map<String, dynamic> params) async {
    final sendPort = params['sendPort'] as SendPort;
    await _runImagePipeline(params, sendPort.send);
  }

  static Future<Map<String, dynamic>> _renderWatermarkedImageBytes({
    required Uint8List inputBytes,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    required WatermarkFont font,
    required int jpegQuality,
    int? targetSize,
    bool forcePng = false,
    required String filePath,
    required String originalExtension,
    bool preserveMetadata = false,
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    bool digitallySign = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    Map<String, Uint8List>? preRenderedStamps,
    FutureOr<void> Function(Map<String, dynamic>)? sendProgress,
  }) async {
    await sendProgress
        ?.call({'progress': 0.05, 'message': 'progressDecodingImage'});

    // Check if image resolution exceeds limits BEFORE attempting to decode
    // This prevents memory exhaustion from ultra-high-resolution images (>50MP)
    _checkResolutionBeforeDecode(inputBytes, originalExtension, filePath);

    // Try to decode the image with multiple fallback strategies
    img.Image? decoded;
    Exception? lastError;
    Uint8List? sanitized;
    final List<String> attemptedStrategies = []; // Track what we tried

    try {
      attemptedStrategies.add('decodeImage');
      decoded = img.decodeImage(inputBytes);
    } catch (e) {
      lastError = e as Exception;

      // Fallback strategies for JPEGs with issues
      if (originalExtension == '.jpg' || originalExtension == '.jpeg') {
        // Fallback 1: Try TIFF decoder first (Samsung wraps JPEG in TIFF)
        try {
          attemptedStrategies.add('decodeTiff');
          decoded = img.decodeTiff(inputBytes);
          lastError = null; // Success!
        } catch (e1) {
          lastError = e1 as Exception;

          // Fallback 2: Try specific JPEG decoder
          try {
            attemptedStrategies.add('decodeJpg');
            decoded = img.decodeJpg(inputBytes);
            lastError = null; // Success!
          } catch (e2) {
            lastError = e2 as Exception;

            // Fallback 3: Strip RST markers and try general decoder
            try {
              attemptedStrategies.add('sanitized+decodeImage');
              sanitized = _sanitizeJpegMarkers(inputBytes);
              decoded = img.decodeImage(sanitized);
              lastError = null; // Success!
            } catch (e3) {
              lastError = e3 as Exception;

              // Fallback 4: Sanitized + TIFF decoder
              if (sanitized != null) {
                try {
                  attemptedStrategies.add('sanitized+decodeTiff');
                  decoded = img.decodeTiff(sanitized);
                  lastError = null; // Success!
                } catch (e4) {
                  lastError = e4 as Exception;

                  // Fallback 5: Sanitized + JPEG decoder
                  try {
                    attemptedStrategies.add('sanitized+decodeJpg');
                    decoded = img.decodeJpg(sanitized);
                    lastError = null; // Success!
                  } catch (e5) {
                    lastError = e5 as Exception;
                  }
                }
              }
            }
          }
        }
      }

      // If all fallbacks failed, throw detailed error
      if (decoded == null && lastError != null) {
        String message;
        final camera = _detectCameraModel(inputBytes);
        final cameraInfo = camera != null ? ' from $camera' : '';

        if (lastError.toString().contains('Unknown JPEG marker')) {
          message = camera != null
              ? 'JPEG from $camera contains unsupported markers. Try re-saving in a photo editor.'
              : 'JPEG contains unsupported markers. Try re-saving in a photo editor.';
        } else if (lastError.toString().contains('Not a valid JPEG')) {
          message = 'Invalid JPEG format. The file may be corrupted.';
        } else if (camera != null && camera.contains('Samsung')) {
          // Samsung-specific error message
          message =
              'Unable to decode image$cameraInfo. Samsung cameras use a TIFF-wrapped JPEG format '
              'that is not fully supported. Please convert the image using:\n'
              '1. Open in a photo editor and save as standard JPEG\n'
              '2. Use an online converter\n'
              '3. Take a screenshot of the image';
        } else {
          message =
              'Failed to decode image after ${attemptedStrategies.length} attempts: '
              '${attemptedStrategies.join(", ")}. '
              'The file may be corrupted or use unsupported features.';
        }

        throw WatermarkError(
            type: WatermarkErrorType.invalidImageData,
            message: message,
            filePath: filePath,
            originalError: lastError);
      }
    }

    if (decoded == null) {
      // Final fallback - check for Samsung camera
      final camera = _detectCameraModel(inputBytes);
      String message;

      if (camera != null && camera.contains('Samsung')) {
        // Samsung-specific error message
        final cameraInfo = ' from $camera';
        message =
            'Unable to decode image$cameraInfo. Samsung cameras use a TIFF-wrapped JPEG format '
            'that is not fully supported. Please convert the image using:\n'
            '1. Open in a photo editor and save as standard JPEG\n'
            '2. Use an online converter\n'
            '3. Take a screenshot of the image';
      } else if (attemptedStrategies.isNotEmpty) {
        message =
            'Failed to decode image after ${attemptedStrategies.length} attempts: '
            '${attemptedStrategies.join(", ")}. '
            'The file may be corrupted or use an unsupported format.';
      } else {
        message =
            'Unable to decode image. The file may be corrupted or in an unsupported format.';
      }

      throw WatermarkError(
          type: WatermarkErrorType.invalidImageData,
          message: message,
          filePath: filePath);
    }

    await sendProgress
        ?.call({'progress': 0.15, 'message': 'progressResizingImage'});
    final resized = WatermarkUtils.resizeToTarget(decoded, targetSize);
    var output = img.Image.from(resized);

    // Optimization: Only create baseline copy if heatmap will be generated
    // Saves 33MB+ memory for 4K images when heatmap not needed
    img.Image? baseline;
    if (useSteganography || useAiCloaking || antiAiLevel > 0) {
      baseline = img.Image.from(resized);
    }

    if (useAiCloaking) {
      await sendProgress
          ?.call({'progress': 0.25, 'message': 'progressApplyingCloaking'});
      output = ImageUtils.applyAiCloaking(output);
    }
    if (preserveMetadata && !decoded.exif.isEmpty) {
      output.exif = decoded.exif.clone();
    }

    // Add SecureMark textData metadata
    output.textData ??= {};
    output.textData!['Description'] =
        'SecureMark (https://github.com/aginies/SecureMark)';
    output.textData!['Software'] = 'SecureMark';

    final expected = (steganographyText?.isNotEmpty == true)
        ? steganographyText!
        : watermarkText;

    // IMPORTANT: Apply Robust Steganography (DCT) BEFORE signing
    // because it modifies pixel values significantly.
    if (useRobustSteganography) {
      await sendProgress
          ?.call({'progress': 0.30, 'message': 'progressEmbeddingRobust'});
      output = DctHandler.embedRobustSignature(output, expected);
    }

    await sendProgress
        ?.call({'progress': 0.35, 'message': 'progressApplyingWatermark'});

    final String? integrityText =
        await WatermarkFieldHandler.applyWatermarkField(
            output,
            watermarkText,
            transparency,
            density,
            useRandomColor,
            selectedColorValue,
            fontSize,
            font,
            preRenderedStamps,
            antiAiLevel: antiAiLevel,
            qrConfig: qrConfig,
            digitallySign: digitallySign,
            watermarkType: watermarkType,
            watermarkImageBytes: watermarkImageBytes,
            onProgress: (progress, message) {
      // Map internal progress (0.0-1.0) to watermark range (0.35-0.75)
      sendProgress?.call({
        'progress': 0.35 + (progress * 0.40),
        'message': message,
      });
    });

    if (useSteganography) {
      if (hiddenFileName != null && hiddenFileBytes != null) {
        await sendProgress
            ?.call({'progress': 0.85, 'message': 'progressHidingFile'});
        output = LsbHandler.embedFileIntoImage(
            output, hiddenFileName, hiddenFileBytes,
            password: steganographyPassword, channel: 'g');
      }
      await sendProgress
          ?.call({'progress': 0.88, 'message': 'progressEmbeddingLsb'});
      output = LsbHandler.embedLSB(output, expected,
          password: steganographyPassword, channel: 'b');
      final cHash =
          ForensicUtils.calculateForensicHash(output, excludeRedLSB: true);
      final sHash =
          ForensicUtils.calculateForensicHash(output, excludeAllLSB: true);

      String forensicLink =
          ForensicUtils.generateVerificationLink(expected, cHash, sHash);

      // Combine with existing integrity signature if it exists
      if (integrityText != null) {
        forensicLink = '$integrityText | $forensicLink';
      }

      output = LsbHandler.embedLSB(output, forensicLink,
          password: steganographyPassword, channel: 'r');
    }

    await sendProgress
        ?.call({'progress': 0.90, 'message': 'progressEncodingImage'});
    final outBytes = WatermarkUtils.encodeImageInOriginalFormat(
        output, originalExtension, jpegQuality, forcePng || digitallySign);
    final result = {
      'output': outBytes,
      'width': output.width,
      'height': output.height,
    };
    if (useSteganography || useAiCloaking || antiAiLevel > 0) {
      if (baseline != null) {
        final heatmap = WatermarkUtils.generateHeatmapImage(baseline, output);
        if (heatmap != null) {
          result['heatmap'] =
              Uint8List.fromList(img.encodeJpg(heatmap, quality: 85));
        }
      }
    }
    return result;
  }

  static Future<ProcessResult> _processPdf({
    required File file,
    Uint8List? inputBytes,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    required WatermarkFont font,
    required int jpegQuality,
    bool forcePng = false,
    bool includeTimestamp = false,
    bool preserveMetadata = false,
    bool rasterizePdf = false,
    String filePrefix = 'securemark-',
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    bool digitallySign = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    Uint8List? signingPrivateKey,
    Uint8List? signingPublicKey,
    bool enablePdfSecurity = false,
    String? pdfUserPassword,
    String? pdfOwnerPassword,
    bool pdfAllowPrinting = false,
    bool pdfAllowCopying = false,
    bool pdfAllowEditing = false,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final bytes = inputBytes ?? await file.readAsBytes();

    // Use raster fallback if requested
    if (rasterizePdf) {
      onProgress?.call(0.2, 'Rasterizing PDF (flattening)...');
      return await _processPdfRasterFallback(
          inputBytes: bytes,
          file: file,
          transparency: transparency,
          density: density,
          watermarkText: watermarkText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          font: font,
          jpegQuality: jpegQuality,
          forcePng: forcePng,
          includeTimestamp: includeTimestamp,
          filePrefix: filePrefix,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          useAiCloaking: useAiCloaking,
          digitallySign: digitallySign,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          steganographyPassword: steganographyPassword,
          steganographyText: steganographyText,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          enablePdfSecurity: enablePdfSecurity,
          pdfUserPassword: pdfUserPassword,
          pdfOwnerPassword: pdfOwnerPassword,
          pdfAllowPrinting: pdfAllowPrinting,
          pdfAllowCopying: pdfAllowCopying,
          pdfAllowEditing: pdfAllowEditing,
          onProgress: onProgress,
          cancellationToken: cancellationToken);
    }

    final completer = Completer<dynamic>();
    ReceivePort? receivePort;

    // Message protocol shared by both execution modes (see
    // _runPdfPipeline): log, progress, result, error.
    void handleMessage(dynamic message) {
      if (message is Map) {
        if (message.containsKey('log')) {
          // Forward log from isolate
          onProgress?.call(-1.0, message['log'] as String);
        } else if (message.containsKey('progress') &&
            message.containsKey('message')) {
          // Progress update
          onProgress?.call(
              message['progress'] as double, message['message'] as String);
        } else if (message.containsKey('result')) {
          // Final result
          completer.complete(message['result']);
          receivePort?.close();
        } else if (message.containsKey('error')) {
          // Error occurred
          completer.completeError(message['error']);
          receivePort?.close();
        }
      }
    }

    // Try vector PDF processing, fallback to raster if it fails
    Uint8List outputBytes;
    final params = <String, dynamic>{
      'inputBytes': bytes,
      'transparency': transparency,
      'density': density,
      'watermarkText': watermarkText,
      'useRandomColor': useRandomColor,
      'selectedColorValue': selectedColorValue,
      'fontSize': fontSize,
      'jpegQuality': jpegQuality,
      'forcePng': forcePng,
      'preserveMetadata': preserveMetadata,
      'antiAiLevel': antiAiLevel,
      'watermarkType': watermarkType,
      'watermarkImageBytes': watermarkImageBytes,
      'qrConfig': qrConfig,
      'signingPrivateKey': signingPrivateKey != null
          ? (kIsWeb
              ? signingPrivateKey
              : TransferableTypedData.fromList([signingPrivateKey]))
          : null,
      'signingPublicKey': signingPublicKey,
      'useAiCloaking': useAiCloaking,
      'digitallySign': digitallySign,
      'steganographyPassword': steganographyPassword,
      'useSteganography': useSteganography,
      'useRobustSteganography': useRobustSteganography,
      'steganographyText': steganographyText,
      'hiddenFileName': hiddenFileName,
      'hiddenFileBytes': hiddenFileBytes,
      'enablePdfSecurity': enablePdfSecurity,
      'pdfUserPassword': pdfUserPassword,
      'pdfOwnerPassword': pdfOwnerPassword,
      'pdfAllowPrinting': pdfAllowPrinting,
      'pdfAllowCopying': pdfAllowCopying,
      'pdfAllowEditing': pdfAllowEditing,
    };

    try {
      if (kIsWeb) {
        // The web engine has no isolates — run the same pipeline on the
        // main isolate (see _runImagePipeline).
        await _runPdfPipeline(params, (message) async {
          handleMessage(message);
          await Future<void>.delayed(Duration.zero);
        });
      } else {
        // Create ReceivePort to get progress updates from isolate
        receivePort = ReceivePort();
        receivePort.listen(handleMessage);
        await Isolate.spawn(
            _pdfIsolateEntry, {'sendPort': receivePort.sendPort, ...params});
      }

      outputBytes = await completer.future;
    } catch (e, stackTrace) {
      debugPrint('Vector PDF engine error: $e');
      debugPrint('Stack trace: $stackTrace');
      onProgress?.call(
          0.3, 'Vector engine failed ($e), falling back to raster engine...');

      // Fallback to raster processing
      return await _processPdfRasterFallback(
          inputBytes: bytes,
          file: file,
          transparency: transparency,
          density: density,
          watermarkText: watermarkText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          font: font,
          jpegQuality: jpegQuality,
          forcePng: forcePng,
          includeTimestamp: includeTimestamp,
          filePrefix: filePrefix,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          useAiCloaking: useAiCloaking,
          digitallySign: digitallySign,
          signingPrivateKey: signingPrivateKey,
          signingPublicKey: signingPublicKey,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          steganographyPassword: steganographyPassword,
          steganographyText: steganographyText,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          enablePdfSecurity: enablePdfSecurity,
          pdfUserPassword: pdfUserPassword,
          pdfOwnerPassword: pdfOwnerPassword,
          pdfAllowPrinting: pdfAllowPrinting,
          pdfAllowCopying: pdfAllowCopying,
          pdfAllowEditing: pdfAllowEditing,
          onProgress: onProgress,
          cancellationToken: cancellationToken);
    }

    final outPath = WatermarkUtils.outputPath(
        file.path, '.pdf', includeTimestamp, filePrefix);

    // Rasterize the ORIGINAL first page, then the watermarked one, for the
    // preview and the A/B/C comparison. Rasterization is delegated to a plugin
    // (pdf.js on web) that is not always available: failing to build a preview
    // must not throw away the PDF that was already produced.
    Uint8List? originalBytes;
    Uint8List? previewBytes;
    int? firstPageWidth;
    int? firstPageHeight;
    try {
      onProgress?.call(0.88, 'Rasterizing original...');
      final originalPreview =
          await Printing.raster(bytes, pages: [0], dpi: 72).first;
      originalBytes = await originalPreview.toPng();
      firstPageWidth = originalPreview.width.round();
      firstPageHeight = originalPreview.height.round();

      // Generate a preview of the first page (watermarked)
      onProgress?.call(0.92, 'Generating preview...');
      final preview =
          await Printing.raster(outputBytes, pages: [0], dpi: 72).first;
      previewBytes = await preview.toPng();
    } catch (e) {
      debugPrint('PDF preview rasterization failed: $e');
    }

    // Generate heatmap for A/B/C comparison
    onProgress?.call(0.95, 'Generating heatmap...');
    Uint8List? heatmapBytes;
    if (originalBytes != null && previewBytes != null) {
      final originalImage = img.decodeImage(originalBytes);
      final previewImage = img.decodeImage(previewBytes);
      if (originalImage != null && previewImage != null) {
        final heatmap =
            WatermarkUtils.generateHeatmapImage(originalImage, previewImage);
        if (heatmap != null) {
          heatmapBytes =
              Uint8List.fromList(img.encodeJpg(heatmap, quality: 85));
        }
      }
    }

    final analysis = await analyzeFileAsync(outputBytes, outPath,
        password: steganographyPassword);
    final expected = (steganographyText?.isNotEmpty == true)
        ? steganographyText!
        : watermarkText;

    bool robustVerified = false;
    if (useRobustSteganography) {
      robustVerified = analysis.robustSignature?.startsWith(expected) ?? false;
    }

    final List<String> applied = [];
    if (digitallySign) applied.add('digitallySignTitle');
    if (enablePdfSecurity) applied.add('pdfSecurityTitle');
    if (preserveMetadata) applied.add('preserveMetadata');
    if (qrConfig != null) applied.add('qrWatermarkTitle');
    if (useSteganography) applied.add('steganographyTitle');
    if (useRobustSteganography) applied.add('robustSteganographyTitle');
    if (useAiCloaking) applied.add('aiCloakingTitle');
    if (antiAiLevel > 0) applied.add('antiAiProtectionTitle');

    return ProcessResult(
        outputPath: outPath,
        outputBytes: outputBytes,
        previewBytes: previewBytes,
        originalBytes: originalBytes,
        heatmapBytes: heatmapBytes,
        steganographyVerified: analysis.signature != null ||
            analysis.file != null ||
            analysis.integrityVerified,
        robustVerified: robustVerified,
        isPdf: true,
        width: firstPageWidth,
        height: firstPageHeight,
        appliedFeatures: applied);
  }

  /// Runs the PDF pipeline, reporting through [send] with the message
  /// protocol {'log'}, {'progress','message'}, {'result'} or {'error'}.
  ///
  /// On native this body runs inside a spawned isolate; on web the engine
  /// has no isolates at all, so the same code runs on the main isolate.
  static Future<void> _runPdfPipeline(Map<String, dynamic> params,
      FutureOr<void> Function(Map<String, dynamic>) send) async {
    IdentityManager.onLog = (msg) => send({'log': msg});

    try {
      final signingPrivateKey = _bytesFromParam(params['signingPrivateKey']);
      final signingPublicKey = params['signingPublicKey'] as Uint8List?;

      if (signingPrivateKey != null && signingPublicKey != null) {
        IdentityManager.initFromKeys(signingPrivateKey, signingPublicKey);
      }

      final result = await _renderWatermarkedPdfBytes(
        inputBytes: params['inputBytes'] as Uint8List,
        transparency: params['transparency'] as double,
        density: params['density'] as double,
        watermarkText: params['watermarkText'] as String,
        useRandomColor: params['useRandomColor'] as bool,
        selectedColorValue: params['selectedColorValue'] as int,
        fontSize: params['fontSize'] as double,
        preserveMetadata: params['preserveMetadata'] as bool,
        antiAiLevel: params['antiAiLevel'] as double,
        watermarkType: params['watermarkType'] as WatermarkType,
        watermarkImageBytes: params['watermarkImageBytes'] as Uint8List?,
        qrConfig: params['qrConfig'] as QrWatermarkConfig?,
        useAiCloaking: params['useAiCloaking'] as bool,
        digitallySign: params['digitallySign'] as bool,
        steganographyPassword: params['steganographyPassword'] as String?,
        useSteganography: params['useSteganography'] as bool,
        useRobustSteganography: params['useRobustSteganography'] as bool,
        steganographyText: params['steganographyText'] as String?,
        hiddenFileName: params['hiddenFileName'] as String?,
        hiddenFileBytes: params['hiddenFileBytes'] as Uint8List?,
        enablePdfSecurity: params['enablePdfSecurity'] as bool,
        pdfUserPassword: params['pdfUserPassword'] as String?,
        pdfOwnerPassword: params['pdfOwnerPassword'] as String?,
        pdfAllowPrinting: params['pdfAllowPrinting'] as bool,
        pdfAllowCopying: params['pdfAllowCopying'] as bool,
        pdfAllowEditing: params['pdfAllowEditing'] as bool,
        sendProgress: send,
      );

      send({'result': result});
    } catch (e) {
      send({'error': e});
    }
  }

  // Isolate entry point for PDF processing with progress reporting
  static void _pdfIsolateEntry(Map<String, dynamic> params) async {
    final sendPort = params['sendPort'] as SendPort;
    await _runPdfPipeline(params, sendPort.send);
  }

  /// PDF Rasterization Fallback - converts PDF to images and watermarks pixel-by-pixel
  /// Used when: 1) User enables "Rasterize PDF" option, or 2) Vector PDF processing fails
  static Future<ProcessResult> _processPdfRasterFallback({
    required Uint8List inputBytes,
    required File file,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    required WatermarkFont font,
    required int jpegQuality,
    int? targetSize,
    bool forcePng = false,
    bool includeTimestamp = false,
    bool preserveMetadata = false,
    String filePrefix = 'securemark-',
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    bool digitallySign = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    Uint8List? signingPrivateKey,
    Uint8List? signingPublicKey,
    bool enablePdfSecurity = false,
    String? pdfUserPassword,
    String? pdfOwnerPassword,
    bool pdfAllowPrinting = false,
    bool pdfAllowCopying = false,
    bool pdfAllowEditing = false,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final List<String> applied = [];
    applied.add('rasterizePdfTitle');
    if (useSteganography) applied.add('steganographyTitle');
    if (useRobustSteganography) applied.add('robustSteganographyTitle');
    if (digitallySign) applied.add('digitallySignTitle');
    if (useAiCloaking) applied.add('aiCloakingTitle');
    if (antiAiLevel > 0) applied.add('antiAiProtectionTitle');
    if (qrConfig != null) applied.add('qrWatermarkTitle');
    if (targetSize != null) applied.add('imageResizingTitle');
    if (preserveMetadata) applied.add('preserveMetadata');
    if (enablePdfSecurity) applied.add('pdfSecurityTitle');

    try {
      final doc = pw.Document();
      Uint8List? preview;
      var hasPages = false;
      var pageCount = 0;
      var processed = 0;
      Uint8List? firstPageOriginal;
      int? firstPageWidth;
      int? firstPageHeight;

      // Rasterize each PDF page and apply watermarks
      await for (final page in Printing.raster(inputBytes, dpi: 150)) {
        if (cancellationToken?.isCancelled == true) {
          throw const WatermarkError(
            type: WatermarkErrorType.operationCancelled,
            message: 'Operation cancelled during PDF rasterization',
          );
        }

        hasPages = true;
        pageCount++;
        final png = await page.toPng();
        firstPageOriginal ??= png;
        firstPageWidth ??= page.width.round();
        firstPageHeight ??= page.height.round();

        final decoded = img.decodeImage(png);
        if (decoded == null) {
          throw WatermarkError(
            type: WatermarkErrorType.invalidPdfData,
            message: 'Failed to decode PDF page $pageCount',
            filePath: file.path,
          );
        }

        var watermarked = img.Image.from(decoded);

        // Apply AI Cloaking if enabled
        if (useAiCloaking) {
          watermarked = ImageUtils.applyAiCloaking(watermarked);
        }

        // Pre-render TTF stamps if using non-bitmap fonts
        Map<String, Uint8List>? stamps;
        if (watermarkType == WatermarkType.text && !font.isBitmap) {
          try {
            final stampBytes = await _renderTextWithFlutterCanvas(
              text: watermarkText,
              font: font,
              fontSize: fontSize.round(),
              color: const ui.Color.fromARGB(255, 255, 255, 255),
            );
            stamps = {'${font.fontFamily}-${fontSize.round()}': stampBytes};
          } catch (_) {
            // Silently fail or ignore error
          }
        }

        // Calculate progress range for this page
        final pageProgressStart = 0.3 + (processed / (pageCount + 1)) * 0.6;
        final pageProgressEnd = 0.3 + ((processed + 1) / (pageCount + 1)) * 0.6;
        final pageProgressRange = pageProgressEnd - pageProgressStart;

        // Apply watermark field
        await WatermarkFieldHandler.applyWatermarkField(
          watermarked,
          watermarkText,
          transparency,
          density,
          useRandomColor,
          selectedColorValue,
          fontSize,
          font,
          stamps,
          antiAiLevel: antiAiLevel,
          qrConfig: qrConfig,
          digitallySign: digitallySign,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          onProgress: (progress, message) {
            onProgress?.call(
              pageProgressStart + (progress * pageProgressRange),
              'Page ${processed + 1}: $message',
            );
          },
        );

        // Embed robust signature if enabled
        if (useRobustSteganography) {
          final textToEmbed = (steganographyText?.isNotEmpty == true)
              ? steganographyText!
              : watermarkText;
          watermarked =
              DctHandler.embedRobustSignature(watermarked, textToEmbed);
        }

        // Embed steganography if enabled
        if (useSteganography) {
          final textToEmbed = (steganographyText?.isNotEmpty == true)
              ? steganographyText!
              : watermarkText;

          if (hiddenFileName != null && hiddenFileBytes != null) {
            watermarked = LsbHandler.embedFileIntoImage(
              watermarked,
              hiddenFileName,
              hiddenFileBytes,
              password: steganographyPassword,
              channel: 'g',
            );
          }

          // Always embed watermark text as LSB if steganography is enabled
          watermarked = LsbHandler.embedLSB(
            watermarked,
            textToEmbed,
            password: steganographyPassword,
            channel: 'b',
          );
        }

        // Encode as PNG for embedding in PDF
        final encoded =
            Uint8List.fromList(img.encodePng(watermarked, level: 2));
        preview ??= encoded;

        // Add page to output PDF
        doc.addPage(
          pw.Page(
            pageFormat:
                PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.SizedBox.expand(
              child: pw.Image(pw.MemoryImage(encoded), fit: pw.BoxFit.fill),
            ),
          ),
        );

        processed++;
      }

      if (!hasPages) {
        throw WatermarkError(
          type: WatermarkErrorType.invalidPdfData,
          message: 'PDF contains no readable pages',
          filePath: file.path,
        );
      }

      // Save the PDF
      Uint8List outputBytes = await doc.save();

      // Apply PDF security if enabled
      if (enablePdfSecurity) {
        final syncDoc = sync.PdfDocument(inputBytes: outputBytes);
        _applySecurityToSyncDocument(
          syncDoc,
          pdfUserPassword: pdfUserPassword,
          pdfOwnerPassword: pdfOwnerPassword,
          pdfAllowPrinting: pdfAllowPrinting,
          pdfAllowCopying: pdfAllowCopying,
          pdfAllowEditing: pdfAllowEditing,
        );
        final securedBytes = syncDoc.saveSync();
        syncDoc.dispose();
        outputBytes = Uint8List.fromList(securedBytes);
      }

      final outputPath = WatermarkUtils.outputPath(
        file.path,
        '.pdf',
        includeTimestamp,
        filePrefix,
      );

      // Verify steganography if enabled
      bool verified = false;
      bool robustVerified = false;
      if ((useSteganography ||
              useRobustSteganography ||
              digitallySign ||
              hiddenFileName != null) &&
          preview != null) {
        final analysis =
            await analyzeImage(preview, password: steganographyPassword);
        final expectedText = (steganographyText?.isNotEmpty == true)
            ? steganographyText!
            : watermarkText;

        if (useSteganography || hiddenFileName != null || digitallySign) {
          bool allVerified = true;
          if (hiddenFileName != null) {
            allVerified &= (analysis.file != null &&
                analysis.file!.fileName == hiddenFileName);
          }
          if (useSteganography) {
            allVerified &=
                (analysis.signature?.startsWith(expectedText) ?? false);
          }
          if (digitallySign) {
            allVerified &= analysis.integrityVerified;
          }
          verified = allVerified;
        }

        if (useRobustSteganography) {
          robustVerified =
              analysis.robustSignature?.startsWith(expectedText) ?? false;
        }
      }

      return ProcessResult(
        outputPath: outputPath,
        outputBytes: outputBytes,
        previewBytes: preview,
        originalBytes: firstPageOriginal,
        steganographyVerified: verified,
        robustVerified: robustVerified,
        isPdf: true,
        width: firstPageWidth,
        height: firstPageHeight,
        appliedFeatures: applied,
      );
    } catch (e) {
      if (e is WatermarkError) rethrow;
      throw WatermarkError(
        type: WatermarkErrorType.invalidPdfData,
        message: 'Failed to process PDF using raster fallback',
        filePath: file.path,
        originalError: e,
      );
    }
  }

  static Future<Uint8List> _renderWatermarkedPdfBytes({
    required Uint8List inputBytes,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    bool preserveMetadata = false,
    double antiAiLevel = 0.0,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    QrWatermarkConfig? qrConfig,
    bool useAiCloaking = false,
    bool digitallySign = false,
    String? steganographyPassword,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    bool enablePdfSecurity = false,
    String? pdfUserPassword,
    String? pdfOwnerPassword,
    bool pdfAllowPrinting = false,
    bool pdfAllowCopying = false,
    bool pdfAllowEditing = false,
    FutureOr<void> Function(Map<String, dynamic>)? sendProgress,
  }) async {
    sync.PdfDocument document;
    try {
      await sendProgress
          ?.call({'progress': 0.1, 'message': 'progressParsingPdf'});
      document = sync.PdfDocument(inputBytes: inputBytes);
    } catch (e) {
      throw WatermarkError(
        type: WatermarkErrorType.invalidPdfData,
        message: 'The PDF file appears to be malformed or corrupted. Error: $e',
        originalError: e,
      );
    }

    // Apply PDF Security if enabled
    if (enablePdfSecurity) {
      _applySecurityToSyncDocument(
        document,
        pdfUserPassword: pdfUserPassword,
        pdfOwnerPassword: pdfOwnerPassword,
        pdfAllowPrinting: pdfAllowPrinting,
        pdfAllowCopying: pdfAllowCopying,
        pdfAllowEditing: pdfAllowEditing,
      );
    }

    // Set metadata
    final List<String> keywordParts = ['SecureMark', 'Watermark', 'Security'];

    // Determine the text to embed (use custom text if provided, otherwise use watermark text)
    final textToEmbed = (steganographyText?.isNotEmpty == true)
        ? steganographyText!
        : watermarkText;

    // Embed steganography signature if requested
    // Works with either LSB steganography OR robust watermarking flags
    if ((useSteganography || useRobustSteganography) &&
        textToEmbed.isNotEmpty) {
      final sigBytes =
          LsbHandler.encryptSignatureForPdf(textToEmbed, steganographyPassword);
      final encoded = base64Encode(sigBytes);
      keywordParts.add('SecureMarkSig:$encoded');
    }

    // Embed hidden file if provided (only with useSteganography, not robust)
    if (useSteganography && hiddenFileName != null && hiddenFileBytes != null) {
      final fileBytes = LsbHandler.encryptHiddenFileForPdf(
          hiddenFileName, hiddenFileBytes, steganographyPassword);
      keywordParts.add('SecureMarkHidden:${base64Encode(fileBytes)}');
    }

    if (!preserveMetadata) {
      document.documentInformation.author = '';
      document.documentInformation.creator =
          'SecureMark (https://github.com/aginies/SecureMark)';
      document.documentInformation.keywords = keywordParts.join(' ');
      document.documentInformation.producer = 'SecureMark';
      document.documentInformation.subject = '';
      document.documentInformation.title = '';
    } else {
      if (document.documentInformation.creator.isEmpty) {
        document.documentInformation.creator =
            'SecureMark (https://github.com/aginies/SecureMark)';
      }
      // Append steganography data to existing keywords if preserving metadata
      if (keywordParts.length > 3) {
        final existingKeywords = document.documentInformation.keywords;
        if (existingKeywords.isNotEmpty) {
          keywordParts.insert(0, existingKeywords);
        }
        document.documentInformation.keywords = keywordParts.join(' ');
      }
    }

    final pageCount = document.pages.count;
    final alpha = (100 - transparency) / 100.0;
    final pdfFont =
        sync.PdfStandardFont(sync.PdfFontFamily.helvetica, fontSize);

    sync.PdfBitmap? logoBitmap;
    if (watermarkType == WatermarkType.image && watermarkImageBytes != null) {
      logoBitmap = sync.PdfBitmap(watermarkImageBytes);
    }

    await sendProgress
        ?.call({'progress': 0.2, 'message': 'progressAddingLayer'});

    for (var i = 0; i < pageCount; i++) {
      final page = document.pages[i];
      final pageSize = page.size;
      final graphics = page.graphics;

      // Apply AI Cloaking if enabled
      if (useAiCloaking) {
        graphics.save();
        for (var j = 0; j < 100; j++) {
          final x = Random().nextDouble() * pageSize.width;
          final y = Random().nextDouble() * pageSize.height;
          final size = 2.0 + Random().nextDouble() * 3.0;
          graphics.setTransparency(0.02 + Random().nextDouble() * 0.03);
          final color = _randomWatermarkColor(255);
          graphics.drawEllipse(ui.Rect.fromLTWH(x, y, size, size),
              brush: sync.PdfSolidBrush(sync.PdfColor(
                  color.r.toInt(), color.g.toInt(), color.b.toInt())));
        }
        graphics.restore();
      }

      // Calculate watermark grid
      final targetCount = _watermarkCount(
          pageSize.width.toInt(), pageSize.height.toInt(), density);
      final columns = max<int>(
          2,
          sqrt(targetCount *
                  (pageSize.width / max<double>(1.0, pageSize.height)))
              .round());
      final rows = max<int>(2, (targetCount / columns).ceil());

      final cellWidth = pageSize.width / columns;
      final cellHeight = pageSize.height / rows;

      // Apply watermarks
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < columns; col++) {
          graphics.save();
          final color =
              _resolveSyncfusionColor(useRandomColor, selectedColorValue);
          final brush = sync.PdfSolidBrush(color);

          final jitterX = (antiAiLevel / 100.0) *
              (cellWidth * 0.2) *
              (Random().nextDouble() - 0.5);
          final jitterY = (antiAiLevel / 100.0) *
              (cellHeight * 0.2) *
              (Random().nextDouble() - 0.5);

          final x = (col * cellWidth) +
              (Random().nextDouble() * (cellWidth * 0.3)) +
              jitterX;
          final y = (row * cellHeight) +
              (Random().nextDouble() * (cellHeight * 0.3)) +
              jitterY;

          graphics.save();
          graphics.translateTransform(x, y);

          if (watermarkType == WatermarkType.text) {
            final jitterAngle =
                (antiAiLevel / 100.0) * 15.0 * (Random().nextDouble() - 0.5);
            final angle = _randomAngle() + jitterAngle;
            graphics.rotateTransform(angle);
            graphics.setTransparency(alpha);
            graphics.drawString(watermarkText, pdfFont, brush: brush);
          } else if (logoBitmap != null) {
            // Logos are not rotated
            graphics.setTransparency(alpha);
            final aspectRatio = logoBitmap.width / logoBitmap.height;
            final logoWidth = fontSize * aspectRatio;
            graphics.drawImage(
              logoBitmap,
              ui.Rect.fromLTWH(0, 0, logoWidth, fontSize),
            );
          }

          graphics.restore();
        }
      }

      // Add QR code if configured
      if (qrConfig != null && qrConfig.visibleQr) {
        final qrSize = qrConfig.size;
        final qrData = qrConfig.toQrString();

        // Generate QR code image
        final qrImage = WatermarkUtils.generateQrCodeImage(
            data: qrData, size: qrSize.round());
        final qrPngBytes = Uint8List.fromList(img.encodePng(qrImage));
        final qrBitmap = sync.PdfBitmap(qrPngBytes);

        // Calculate QR position on page
        final (qrX, qrY) = WatermarkUtils.calculateQrPosition(
          imageWidth: pageSize.width.toInt(),
          imageHeight: pageSize.height.toInt(),
          qrSize: qrSize.round(),
          position: qrConfig.position,
        );

        // Draw QR code with opacity
        graphics.save();
        graphics.setTransparency(qrConfig.opacity);
        graphics.drawImage(
          qrBitmap,
          ui.Rect.fromLTWH(qrX.toDouble(), qrY.toDouble(), qrSize, qrSize),
        );
        graphics.restore();
      }
    }

    await sendProgress
        ?.call({'progress': 0.9, 'message': 'progressFinalizingPdf'});

    if (digitallySign) {
      // 1. Save the visually watermarked document to get the exact bytes for hashing.
      final bytesToHash = Uint8List.fromList(document.saveSync());
      document.dispose(); // Dispose the original document

      await sendProgress
          ?.call({'progress': 0.95, 'message': 'progressSigningPdf'});

      // 2. Create the signature from the hash of those bytes.
      final hashToStore = sha256.convert(bytesToHash);
      final signature = await IdentityManager.signData(hashToStore.bytes);
      final publicKey = await IdentityManager.getDevicePublicKey();
      IdentityManager.onLog?.call(
          '[SIGN] Generated signature from hash: ${hashToStore.toString()}');

      // 3. Load the watermarked bytes into a new document to add the final metadata.
      final finalDoc = sync.PdfDocument(inputBytes: bytesToHash);

      // 4. Update keywords with integrity info, including the original hash.
      final currentKeywords = finalDoc.documentInformation.keywords;
      final integrityInfo =
          'SecureMarkIntegrity:$signature SecureMarkKey:$publicKey SecureMarkOriginalHash:${hashToStore.toString()}';
      final newKeywords = currentKeywords.isEmpty
          ? integrityInfo
          : '$currentKeywords $integrityInfo';
      finalDoc.documentInformation.keywords = newKeywords;
      IdentityManager.onLog?.call('[SIGN] Updated keywords to: "$newKeywords"');

      // 5. Save the document for the final time with the signature in the metadata.
      final finalBytes = Uint8List.fromList(finalDoc.saveSync());
      finalDoc.dispose();
      return finalBytes;
    }

    // Default path for non-signed documents
    final finalBytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return finalBytes;
  }

  // Helper function for watermark count calculation
  static int _watermarkCount(int w, int h, double d) =>
      max(8, ((w * h / 18000) * 2.69 * (d / 50).clamp(0.4, 2.0)).round());

  // Helper function for random angle
  static double _randomAngle() => Random().nextInt((360 / 15).round()) * 15.0;

  // Helper function for random watermark color
  static img.Color _randomWatermarkColor(int a) {
    final (r, g, b) = ColorUtils.hsvToRgb();
    return img.ColorRgba8(r, g, b, a);
  }

  // Helper function for Syncfusion PDF color
  static sync.PdfColor _resolveSyncfusionColor(
      bool useRandomColor, int selectedColorValue) {
    int r, g, b;
    if (useRandomColor) {
      (r, g, b) = ColorUtils.hsvToRgb();
    } else {
      r = (selectedColorValue >> 16) & 0xFF;
      g = (selectedColorValue >> 8) & 0xFF;
      b = selectedColorValue & 0xFF;
    }
    return sync.PdfColor(r, g, b);
  }

  /// Reads JPEG/PNG image dimensions from file header without full decoding
  ///
  /// This is much faster and memory-efficient than decoding the entire image.
  /// Returns (width, height) or null if unable to determine.
  static (int, int)? _getImageDimensions(Uint8List bytes, String extension) {
    if (extension == '.jpg' || extension == '.jpeg') {
      return _getJpegDimensions(bytes);
    } else if (extension == '.png') {
      return _getPngDimensions(bytes);
    }
    return null;
  }

  /// Reads JPEG dimensions from SOF (Start Of Frame) marker
  ///
  /// JPEG structure: FF D8 (SOI) ... FF Cx (SOF) [len] [precision] [height] [width]
  /// SOF markers: C0-C3, C5-C7, C9-CB, CD-CF (various JPEG encoding types)
  static (int, int)? _getJpegDimensions(Uint8List bytes) {
    try {
      var i = 0;
      // Look for JPEG SOI marker (0xFF 0xD8)
      if (bytes.length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
        return null; // Not a valid JPEG
      }

      i = 2;
      while (i < bytes.length - 9) {
        // Find marker (0xFF followed by non-0xFF)
        if (bytes[i] != 0xFF) {
          i++;
          continue;
        }

        final marker = bytes[i + 1];

        // Skip padding bytes (0xFF 0xFF)
        if (marker == 0xFF) {
          i++;
          continue;
        }

        // SOF markers (Start Of Frame) contain dimensions
        // C0=Baseline, C1=Extended, C2=Progressive, C3=Lossless, C5-C7, C9-CB, CD-CF
        if ((marker >= 0xC0 && marker <= 0xC3) ||
            (marker >= 0xC5 && marker <= 0xC7) ||
            (marker >= 0xC9 && marker <= 0xCB) ||
            (marker >= 0xCD && marker <= 0xCF)) {
          // SOF structure: FF Cx [length-2bytes] [precision-1byte] [height-2bytes] [width-2bytes]
          if (i + 9 < bytes.length) {
            final height = (bytes[i + 5] << 8) | bytes[i + 6];
            final width = (bytes[i + 7] << 8) | bytes[i + 8];
            return (width, height);
          }
        }

        // SOS marker (0xDA) = Start of scan data, dimensions must be before this
        if (marker == 0xDA) {
          return null;
        }

        // Skip to next marker (read segment length)
        if (i + 3 < bytes.length) {
          final segmentLength = (bytes[i + 2] << 8) | bytes[i + 3];
          i += 2 + segmentLength;
        } else {
          break;
        }
      }
    } catch (e) {
      // Silently fail, will fall back to decoding
    }
    return null;
  }

  /// Reads PNG dimensions from IHDR chunk
  ///
  /// PNG structure: [signature-8bytes] [IHDR chunk: length-4, "IHDR"-4, width-4, height-4, ...]
  static (int, int)? _getPngDimensions(Uint8List bytes) {
    try {
      // PNG signature: 137 80 78 71 13 10 26 10
      if (bytes.length < 24 ||
          bytes[0] != 0x89 ||
          bytes[1] != 0x50 ||
          bytes[2] != 0x4E ||
          bytes[3] != 0x47) {
        return null;
      }

      // IHDR chunk starts at byte 8, check for "IHDR" signature
      if (bytes[12] == 0x49 &&
          bytes[13] == 0x48 &&
          bytes[14] == 0x44 &&
          bytes[15] == 0x52) {
        // Width and height are 4-byte big-endian integers
        final width = (bytes[16] << 24) |
            (bytes[17] << 16) |
            (bytes[18] << 8) |
            bytes[19];
        final height = (bytes[20] << 24) |
            (bytes[21] << 16) |
            (bytes[22] << 8) |
            bytes[23];
        return (width, height);
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Checks if image exceeds resolution limits BEFORE decoding
  ///
  /// Throws WatermarkError if image is too large to process safely
  static void _checkResolutionBeforeDecode(
      Uint8List bytes, String extension, String filePath) {
    final dimensions = _getImageDimensions(bytes, extension);
    if (dimensions == null) {
      return; // Can't determine dimensions, let decoder try
    }

    final (width, height) = dimensions;
    final pixelCount = width * height;
    final megapixels = (pixelCount / 1000000).toStringAsFixed(1);

    if (pixelCount > _maxPixelCount) {
      final camera = _detectCameraModel(bytes);
      final cameraInfo = camera != null ? ' (from $camera)' : '';

      throw WatermarkError(
        type: WatermarkErrorType.invalidImageData,
        message:
            'Image resolution ${width}x$height ($megapixels MP)$cameraInfo exceeds '
            'maximum supported resolution of $_maxMegapixels MP. '
            'Please resize the image before watermarking. '
            'Recommended: 4000x4000 or smaller for file sharing.',
        filePath: filePath,
      );
    }
  }

  /// Sanitizes JPEG data by removing unsupported RST (restart) markers
  ///
  /// Some cameras/phones generate JPEGs with RST markers (0xD0-0xD7) that
  /// the image package decoder doesn't handle properly. This strips them out.
  ///
  /// Note: This is a workaround - proper solution would be updating the image package.
  static Uint8List _sanitizeJpegMarkers(Uint8List bytes) {
    final output = BytesBuilder(copy: false);
    var i = 0;

    while (i < bytes.length) {
      // JPEG markers start with 0xFF
      if (bytes[i] == 0xFF && i + 1 < bytes.length) {
        final marker = bytes[i + 1];

        // Skip RST markers (0xD0-0xD7) - these cause "Unknown JPEG marker" errors
        if (marker >= 0xD0 && marker <= 0xD7) {
          i += 2; // Skip the FF Dx marker
          continue;
        }
      }
      output.addByte(bytes[i]);
      i++;
    }

    return output.toBytes();
  }

  /// Detects camera model from EXIF data in JPEG
  ///
  /// Attempts to extract "Model" field from EXIF/TIFF header for better error messages
  static String? _detectCameraModel(Uint8List bytes) {
    try {
      // Look for EXIF marker (0xFF 0xE1) followed by "Exif\0\0"
      for (var i = 0; i < bytes.length - 10; i++) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0xE1) {
          // Check for "Exif\0\0" identifier
          if (bytes[i + 4] == 0x45 &&
              bytes[i + 5] == 0x78 &&
              bytes[i + 6] == 0x69 &&
              bytes[i + 7] == 0x66) {
            // Basic EXIF parsing - look for common camera model strings
            final exifData = String.fromCharCodes(bytes.sublist(
                i, i + 500 < bytes.length ? i + 500 : bytes.length));

            // Common camera brands
            if (exifData.contains('Galaxy')) return 'Samsung Galaxy';
            if (exifData.contains('iPhone')) return 'iPhone';
            if (exifData.contains('Pixel')) return 'Google Pixel';
            if (exifData.contains('Canon')) return 'Canon';
            if (exifData.contains('Nikon')) return 'Nikon';
            if (exifData.contains('Sony')) return 'Sony';

            return null; // EXIF found but no known camera
          }
        }
      }
    } catch (_) {
      // Ignore parsing errors
    }
    return null;
  }

  static Future<AnalysisResult> analyzeFileAsync(
      Uint8List bytes, String fileName,
      {String? password, Function(double, String)? onProgress}) async {
    if (p.extension(fileName).toLowerCase() == '.pdf') {
      final res = await _analyzePdfVector(bytes,
          password: password, onProgress: onProgress);
      if (res.signature != null || res.file != null || res.integrityVerified) {
        return res;
      }
      return const AnalysisResult();
    }
    return await analyzeImage(bytes,
        password: password, onProgress: onProgress);
  }

  static Future<AnalysisResult> analyzeImageAsync(Uint8List bytes,
      {String? password}) async {
    return await analyzeImage(bytes, password: password);
  }

  /// Convenience method to extract a hidden file from an image
  static Future<ExtractedFileResult?> extractFileAsync(Uint8List imageBytes,
      {String? password}) async {
    final analysis = await analyzeImage(imageBytes, password: password);
    return analysis.file;
  }

  static Future<AnalysisResult> _analyzePdfVector(Uint8List bytes,
      {String? password, Function(double, String)? onProgress}) async {
    try {
      onProgress?.call(0.1, 'progressReadingPdf');
      final doc = sync.PdfDocument(inputBytes: bytes);
      onProgress?.call(0.3, 'progressParsingPdf');
      final kw = doc.documentInformation.keywords;
      String? sig;
      ExtractedFileResult? file;
      String? integritySig;
      String? publicKey;
      String? originalHash;

      final kwParts = kw.split(' ');
      for (var i = 0; i < kwParts.length; i++) {
        final part = kwParts[i];
        final progress = 0.3 + (0.4 * (i / kwParts.length));
        onProgress?.call(progress, 'progressParsingPdf');

        if (part.startsWith('SecureMarkHidden:')) {
          final encoded = part.substring(17);
          try {
            final decoded = base64Decode(encoded);
            file = LsbHandler.decryptHiddenFileFromPdf(decoded, password);
          } catch (_) {
            // Silently fail or ignore error
          }
        }
        if (part.startsWith('SecureMarkSig:')) {
          final encoded = part.substring(14);
          try {
            final decoded = base64Decode(encoded);
            sig = _parseSignatureFromPayload(decoded, password);
          } catch (_) {
            // Silently fail or ignore error
          }
        }
        if (part.startsWith('SecureMarkIntegrity:')) {
          integritySig = part.substring(20);
        }
        if (part.startsWith('SecureMarkKey:')) {
          publicKey = part.substring(14);
        }
        if (part.startsWith('SecureMarkOriginalHash:')) {
          originalHash = part.substring(23);
        }
      }

      bool integrityVerified = false;
      if (integritySig != null && publicKey != null && originalHash != null) {
        onProgress?.call(0.8, 'progressVerifyingStegano');
        IdentityManager.onLog
            ?.call('[VERIFY] Found integrity signature. Verifying...');

        // The integrity verification works as follows:
        // 1. The originalHash is a SHA-256 hash (hex string) of the document BEFORE integrity metadata was added
        // 2. That hash was signed with the private key, producing integritySig
        // 3. We verify the signature using the public key to prove authenticity

        // Convert the hex hash string back to bytes for signature verification
        final hashBytes = hex.decode(originalHash);

        // Verify the cryptographic signature
        final SignatureVerification cryptoSignature =
            await IdentityManager.verifySignature(
                hashBytes, integritySig, publicKey);

        IdentityManager.onLog
            ?.call('[VERIFY] Crypto signature verification: $cryptoSignature');

        // The signature verification proves:
        // - The document hash was created by the holder of the private key
        // - The hash has not been tampered with
        // - The document content (when originally signed) matches the hash
        //
        // Only a positive verification counts as integrity proven. A corrupt
        // signature (error) is not evidence of tampering, but it is not proof
        // of integrity either.
        integrityVerified = cryptoSignature == SignatureVerification.valid;

        IdentityManager.onLog?.call(
            '[VERIFY] Final integrity verification result: $integrityVerified');
      }

      doc.dispose();
      return AnalysisResult(
        signature: sig,
        file: file,
        integrityVerified: integrityVerified,
        senderPublicKey: publicKey,
      );
    } catch (e, stackTrace) {
      IdentityManager.onLog
          ?.call('[VERIFY] Error during PDF analysis: $e\n$stackTrace');
      return const AnalysisResult();
    }
  }

  static Future<AnalysisResult> analyzeImage(Uint8List bytes,
      {String? password, Function(double, String)? onProgress}) async {
    onProgress?.call(0.1, 'progressDecodingImage');
    // Use compute to decode image in a separate isolate to avoid blocking UI thread
    final image = await compute(img.decodeImage, bytes);
    if (image == null) {
      return const AnalysisResult();
    }
    String? sig;
    ExtractedFileResult? file;
    VerificationResult? verif;
    String? integritySig;
    String? publicKey;

    onProgress?.call(0.3, 'progressValidating');
    final cHash =
        ForensicUtils.calculateForensicHash(image, excludeRedLSB: true);
    final sHash =
        ForensicUtils.calculateForensicHash(image, excludeAllLSB: true);

    final channels = ['b', 'g', 'r'];
    for (var i = 0; i < channels.length; i++) {
      final chan = channels[i];
      final progress = 0.4 + (0.4 * (i / channels.length));
      onProgress?.call(progress, 'progressVerifyingStegano');

      // 1. Try to extract a hidden file (always Green channel)
      if (chan == 'g') {
        file = LsbHandler.extractFileFromImage(
            image, password != null, password,
            channel: 'g');
        if (file != null) {
          IdentityManager.onLog
              ?.call('Found hidden file in Green channel: ${file.fileName}');
        }
      }

      // 2. Try to extract text with password (for normal LSB signatures)
      final textWithPassword = LsbHandler.extractTextFromImage(
          image, password != null, password,
          channel: chan);
      if (textWithPassword != null) {
        IdentityManager.onLog?.call(
            'Found text with password in $chan: ${textWithPassword.substring(0, min(textWithPassword.length, 30))}...');
      }

      // 3. Try to extract text WITHOUT password (for forensic links and integrity info)
      final textPlain =
          LsbHandler.extractTextFromImage(image, false, null, channel: chan);
      if (textPlain != null) {
        IdentityManager.onLog?.call(
            'Found plain text in $chan: ${textPlain.substring(0, min(textPlain.length, 30))}...');
      }

      // Process findings from either pass
      for (final rawText in [textWithPassword, textPlain]) {
        if (rawText == null) continue;

        // Split by | in case we combined multiple system messages (e.g. Signature | Forensic Link)
        final parts = rawText.split(' | ');
        if (parts.length > 1) {
          IdentityManager.onLog
              ?.call('Split combined text into ${parts.length} parts');
        }

        for (final text in parts) {
          final trimmedText = text.trim();
          if (trimmedText.startsWith('securemark://verify')) {
            IdentityManager.onLog
                ?.call('Processing forensic verification link');
            verif ??= ForensicUtils.verifyDeepLink(trimmedText, cHash, sHash);
          } else if (trimmedText.startsWith('SecureMarkIntegrity:')) {
            IdentityManager.onLog
                ?.call('Processing digital integrity signature');
            if (integritySig == null) {
              final infoParts = trimmedText.split(' ');
              for (final part in infoParts) {
                if (part.startsWith('SecureMarkIntegrity:')) {
                  integritySig = part.substring(20);
                } else if (part.startsWith('SecureMarkKey:')) {
                  publicKey = part.substring(14);
                }
              }
              IdentityManager.onLog?.call(
                  'Extracted Integrity Sig (len: ${integritySig?.length}) and Public Key (len: ${publicKey?.length})');
            }
          } else if (!trimmedText.contains('[ENCRYPTED]')) {
            sig ??= trimmedText;
          }
        }
      }
    }

    bool integrityVerified = false;
    onProgress?.call(0.9, 'progressVerifyingStegano');
    if (integritySig != null && publicKey != null) {
      IdentityManager.onLog
          ?.call('Verifying digital signature with public key...');
      // Use forensic hash excluding ALL LSBs (where signatures live)
      final hash =
          ForensicUtils.calculateForensicHashBytes(image, excludeAllLSB: true);
      final SignatureVerification verification =
          await IdentityManager.verifySignature(
              hash.bytes, integritySig, publicKey);
      // Only a positive verification counts as integrity proven; a corrupt
      // signature (error) is not evidence of tampering.
      integrityVerified = verification == SignatureVerification.valid;
      IdentityManager.onLog
          ?.call('Signature verification result: $verification');
    } else {
      if (integritySig == null) {
        IdentityManager.onLog
            ?.call('No integrity signature found in any channel.');
      }
      if (publicKey == null) {
        IdentityManager.onLog?.call('No public key found in image metadata.');
      }
    }

    return AnalysisResult(
      signature: sig,
      robustSignature: DctHandler.extractRobustSignature(image),
      file: file,
      verification: verif,
      integrityVerified: integrityVerified,
      senderPublicKey: publicKey,
    );
  }

  static String? _parseSignatureFromPayload(Uint8List p, String? pw) {
    // Format: [header(2)] [reserved(2)] [length(4)] [data] [crc(2)]
    // Minimum: 2 + 2 + 4 + 0 + 2 = 10 bytes
    if (p.length < 10) {
      return null;
    }
    // Length is at bytes 4-7 (after 2-byte header + 2-byte reserved)
    final len = (p[4] << 24) | (p[5] << 16) | (p[6] << 8) | p[7];
    if (p.length < 8 + len + 2) {
      return null;
    }

    final header = utf8.decode(p.sublist(0, 2));
    final isEncrypted = header == 'SX';
    // Data starts at byte 8 (after header + reserved + length)
    Uint8List payloadBytes = Uint8List.fromList(p.sublist(8, 8 + len));
    final extractedCrc = (p[8 + len] << 8) | p[8 + len + 1];

    if (isEncrypted) {
      if (pw == null || pw.isEmpty) {
        return '[ENCRYPTED] (Password required)';
      }
      final decrypted = EncryptionUtils.decryptBytes(payloadBytes, pw);
      if (decrypted == null) {
        return '[ENCRYPTED] (Wrong password)';
      }
      payloadBytes = decrypted;
    }
    final calculatedCrc = EncryptionUtils.crc16(payloadBytes);
    if (calculatedCrc != extractedCrc) {
      return isEncrypted ? '[ENCRYPTED] (Wrong password)' : null;
    }
    try {
      final result = utf8.decode(payloadBytes, allowMalformed: true);
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Render text using Flutter's canvas for TTF fonts
  static Future<Uint8List> _renderTextWithFlutterCanvas({
    required String text,
    required WatermarkFont font,
    required int fontSize,
    required ui.Color color,
  }) async {
    final textStyle = font.getTextStyle(
      fontSize: fontSize.toDouble(),
      fontWeight: FontWeight.normal,
    );
    final textSpan =
        TextSpan(text: text, style: textStyle.copyWith(color: color));
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    textPainter.paint(canvas, ui.Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      textPainter.width.ceil(),
      textPainter.height.ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Applies security settings to a Syncfusion PDF document
  static void _applySecurityToSyncDocument(
    sync.PdfDocument document, {
    required String? pdfUserPassword,
    required String? pdfOwnerPassword,
    required bool pdfAllowPrinting,
    required bool pdfAllowCopying,
    required bool pdfAllowEditing,
  }) {
    final security = document.security;
    security.algorithm = sync.PdfEncryptionAlgorithm.aesx256Bit;
    security.userPassword = pdfUserPassword ?? '';
    security.ownerPassword =
        (pdfOwnerPassword != null && pdfOwnerPassword.isNotEmpty)
            ? pdfOwnerPassword
            : (pdfUserPassword ?? '');

    // Configure permissions
    security.permissions.addAll([
      if (pdfAllowPrinting) sync.PdfPermissionsFlags.print,
      if (pdfAllowCopying) sync.PdfPermissionsFlags.copyContent,
      if (pdfAllowEditing) sync.PdfPermissionsFlags.editAnnotations,
      if (pdfAllowEditing) sync.PdfPermissionsFlags.editContent,
      if (pdfAllowEditing) sync.PdfPermissionsFlags.fillFields,
    ]);
  }
}
