import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

/// Network interface information with IP classification
class NetworkInterfaceInfo {
  final String ipAddress;
  final String interfaceName;
  final InternetAddressType type;
  final bool isExternal;

  const NetworkInterfaceInfo({
    required this.ipAddress,
    required this.interfaceName,
    required this.type,
    required this.isExternal,
  });

  String get displayName {
    final typeStr = type == InternetAddressType.IPv4 ? 'IPv4' : 'IPv6';
    final networkType = isExternal ? 'External' : 'Internal';
    return '$ipAddress ($interfaceName - $typeStr - $networkType)';
  }

  /// Check if IP is in private range (RFC 1918)
  static bool isPrivateIp(String ip) {
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 16 && second <= 31) return true;
      }
    }
    if (ip.startsWith('169.254.')) return true; // Link-local
    if (ip.startsWith('127.')) return true; // Loopback
    return false;
  }
}

class LocalServerManager {
  static HttpServer? _server;
  static Uint8List? _fileBytes; // For in-memory data (encrypted files)
  static String? _filePath; // For streaming from disk
  static int? _fileSize;
  static String? _fileName;
  static String? _token;
  static StreamController<void>? _cancelController; // For cancellation

  static bool get isRunning => _server != null;
  static const int chunkSize = 64 * 1024; // 64 KB chunks

  /// Get all network interfaces with classification (internal/external)
  static Future<List<NetworkInterfaceInfo>> getNetworkInterfaces({
    bool includeLoopback = false,
    bool ipv4Only = true,
  }) async {
    final List<NetworkInterfaceInfo> interfaces = [];
    try {
      final networkInterfaces = await NetworkInterface.list(
        includeLoopback: includeLoopback,
        type: ipv4Only ? InternetAddressType.IPv4 : InternetAddressType.any,
      );

      for (final interface in networkInterfaces) {
        for (final addr in interface.addresses) {
          final isExternal = !NetworkInterfaceInfo.isPrivateIp(addr.address);
          interfaces.add(NetworkInterfaceInfo(
            ipAddress: addr.address,
            interfaceName: interface.name,
            type: addr.type,
            isExternal: isExternal,
          ));
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error getting network interfaces: $e');
    }
    return interfaces;
  }

  /// Legacy method - returns just IP addresses (for backward compatibility)
  static Future<List<String>> getLocalIps() async {
    final interfaces = await getNetworkInterfaces();
    return interfaces.map((i) => i.ipAddress).toList();
  }

  /// Start server with in-memory bytes (for encrypted data)
  static Future<int> startServer(
    Uint8List bytes,
    String name, {
    VoidCallback? onDone,
    Function(int, int)? onProgress,
    String? bindAddress, // Specific IP to bind to
  }) async {
    if (_server != null) {
      await stopServer();
    }

    _fileBytes = bytes;
    _filePath = null;
    _fileSize = bytes.length;
    _fileName = name;
    _token = _generateRandomToken();
    _cancelController = StreamController<void>.broadcast();

    return _startHttpServer(
      onDone: onDone,
      onProgress: onProgress,
      bindAddress: bindAddress,
    );
  }

  /// Start server streaming from file path (memory-efficient for large files)
  static Future<int> startServerFromFile(
    String filePath, {
    VoidCallback? onDone,
    Function(int, int)? onProgress,
    String? bindAddress, // Specific IP to bind to
  }) async {
    if (_server != null) {
      await stopServer();
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    _filePath = filePath;
    _fileBytes = null;
    _fileSize = await file.length();
    _fileName = filePath.split('/').last;
    _token = _generateRandomToken();
    _cancelController = StreamController<void>.broadcast();

    return _startHttpServer(
      onDone: onDone,
      onProgress: onProgress,
      bindAddress: bindAddress,
    );
  }

  /// Internal method to start HTTP server
  static Future<int> _startHttpServer({
    VoidCallback? onDone,
    Function(int, int)? onProgress,
    String? bindAddress,
  }) async {
    // Bind to specific address or all IPv4 interfaces
    final address = bindAddress != null
        ? InternetAddress(bindAddress)
        : InternetAddress.anyIPv4;

    // ignore: avoid_print
    print('[LocalServer] Binding to: ${address.address}');
    _server = await HttpServer.bind(address, 0);
    // ignore: avoid_print
    print(
        '[LocalServer] Server started on ${address.address}:${_server!.port}');

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      // ignore: avoid_print
      print(
          '[LocalServer] Request from ${request.connectionInfo?.remoteAddress.address}: $path');
      if (path == '/$_token/download') {
        request.response.headers.contentType =
            ContentType.parse('application/octet-stream');
        request.response.headers
            .add('Content-Disposition', 'attachment; filename="$_fileName"');
        request.response.contentLength = _fileSize!;

        try {
          if (_fileBytes != null) {
            // In-memory: send in chunks to avoid blocking
            await _streamBytesInChunks(
              request.response,
              _fileBytes!,
              onProgress: onProgress,
            );
          } else if (_filePath != null) {
            // Stream from file
            await _streamFileInChunks(
              request.response,
              _filePath!,
              onProgress: onProgress,
            );
          }

          await request.response.close();

          // One-shot: stop server after successful download
          await stopServer();
          onDone?.call();
        } catch (e) {
          // ignore: avoid_print
          print('Error serving file: $e');
          await request.response.close();
          await stopServer();
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found')
          ..close();
      }
    });

    return _server!.port;
  }

  /// Stream bytes in chunks (for in-memory data)
  static Future<void> _streamBytesInChunks(
    HttpResponse response,
    Uint8List data, {
    Function(int, int)? onProgress,
  }) async {
    int offset = 0;
    final total = data.length;

    while (offset < total) {
      // Check for cancellation
      if (_cancelController?.isClosed ?? false) {
        throw Exception('Transfer cancelled by user');
      }

      final end = (offset + chunkSize < total) ? offset + chunkSize : total;
      final chunk = data.sublist(offset, end);
      response.add(chunk);

      offset = end;
      onProgress?.call(offset, total);

      // Yield to event loop to prevent blocking
      await Future.delayed(Duration.zero);
    }
  }

  /// Stream file in chunks (memory-efficient)
  static Future<void> _streamFileInChunks(
    HttpResponse response,
    String filePath, {
    Function(int, int)? onProgress,
  }) async {
    final file = File(filePath);
    final stream = file.openRead();
    int bytesSent = 0;
    final total = _fileSize!;

    await for (final chunk in stream) {
      // Check for cancellation
      if (_cancelController?.isClosed ?? false) {
        throw Exception('Transfer cancelled by user');
      }

      response.add(chunk);
      bytesSent += chunk.length;
      onProgress?.call(bytesSent, total);
    }
  }

  /// Cancel active transfer
  static Future<void> cancelTransfer() async {
    if (_cancelController != null && !_cancelController!.isClosed) {
      await _cancelController!.close();
    }
    await stopServer();
  }

  static Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    _fileBytes = null;
    _filePath = null;
    _fileSize = null;
    _fileName = null;
    _token = null;

    // Clean up cancel controller
    if (_cancelController != null && !_cancelController!.isClosed) {
      await _cancelController!.close();
    }
    _cancelController = null;
  }

  static String? get token => _token;
  static String? get currentFileName => _fileName;
  static int? get currentFileSize => _fileSize;

  static Future<int> startReceiveServer(
      Function(String fileName, String remoteAddr, {String? filePath})
          onFileReceived,
      {VoidCallback? onDone,
      Function(int, int)? onProgress,
      String? bindAddress}) async {
    if (_server != null) {
      await stopServer();
    }

    _token = _generateRandomToken();
    _cancelController = StreamController<void>.broadcast();

    // Bind to specific address or all IPv4 interfaces
    final address = bindAddress != null
        ? InternetAddress(bindAddress)
        : InternetAddress.anyIPv4;

    // ignore: avoid_print
    print('[ReceiveServer] Binding to: ${address.address}');
    _server = await HttpServer.bind(address, 0);
    // ignore: avoid_print
    print(
        '[ReceiveServer] Server started on ${address.address}:${_server!.port}');

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      // ignore: avoid_print
      print(
          '[ReceiveServer] Request from ${request.connectionInfo?.remoteAddress.address}: ${request.method} $path');
      if (request.method == 'POST' && path == '/$_token/upload') {
        Directory? tempDir;
        try {
          final fileName =
              request.headers.value('x-file-name') ?? 'uploaded_file';
          final contentLength = request.contentLength;

          // Stream to temp file (memory-efficient!)
          tempDir = await Directory.systemTemp.createTemp('upload_');
          final tempFile = File('${tempDir.path}/$fileName');
          final sink = tempFile.openWrite();

          int receivedBytes = 0;

          // ignore: avoid_print
          print(
              '[ReceiveServer] Streaming upload to temp file: ${tempFile.path}');

          await for (final chunk in request) {
            // Check for cancellation
            if (_cancelController?.isClosed ?? false) {
              await sink.close();
              throw Exception('Transfer cancelled by user');
            }

            sink.add(chunk);
            receivedBytes += chunk.length;

            // Report progress if content length is known
            if (contentLength > 0 && onProgress != null) {
              onProgress(receivedBytes, contentLength);
            }
          }

          await sink.flush();
          await sink.close();

          // ignore: avoid_print
          print(
              '[ReceiveServer] Upload complete: $receivedBytes bytes streamed to disk');

          // Call callback with file path (memory-efficient - no reloading!)
          onFileReceived(
            fileName,
            request.connectionInfo?.remoteAddress.address ?? 'unknown',
            filePath: tempFile.path,
          );

          request.response.statusCode = HttpStatus.ok;
          request.response.write('OK');
          await request.response.close();

          // One-shot: stop server after successful upload
          await stopServer();
          onDone?.call();
        } catch (e) {
          // ignore: avoid_print
          print('[ReceiveServer] Error: $e');
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Error: $e')
            ..close();

          // Cleanup temp directory on error
          if (tempDir != null) {
            try {
              await tempDir.delete(recursive: true);
            } catch (_) {}
          }
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found')
          ..close();
      }
    });

    return _server!.port;
  }

  /// Generates a cryptographically secure token with 256 bits of entropy
  static String _generateRandomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    // Use base64Url for URL-safe encoding, remove padding
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generates a separate encryption key (independent from URL access token)
  /// Returns a base64-encoded 256-bit key suitable for AES-256 encryption
  static String generateEncryptionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(bytes); // Standard base64 for encryption key
  }
}
