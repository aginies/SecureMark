import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'certificate_manager.dart';

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
  static Completer<void>?
      _transferCompleteCompleter; // Wait for client acknowledgment

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
      debugPrint('Error getting network interfaces: $e');
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
    _transferCompleteCompleter = Completer<void>();

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
    _transferCompleteCompleter = Completer<void>();

    return _startHttpServer(
      onDone: onDone,
      onProgress: onProgress,
      bindAddress: bindAddress,
    );
  }

  /// Start HTTPS server with in-memory bytes (for encrypted data)
  static Future<int> startServerSecure(
    Uint8List bytes,
    String name, {
    VoidCallback? onDone,
    Function(int, int)? onProgress,
    String? bindAddress,
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
    _transferCompleteCompleter = Completer<void>();

    return _startHttpsServer(
      onDone: onDone,
      onProgress: onProgress,
      bindAddress: bindAddress,
    );
  }

  /// Start HTTPS server streaming from file path (memory-efficient for large files)
  static Future<int> startServerFromFileSecure(
    String filePath, {
    VoidCallback? onDone,
    Function(int, int)? onProgress,
    String? bindAddress,
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
    _transferCompleteCompleter = Completer<void>();

    return _startHttpsServer(
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

    debugPrint('[LocalServer] Binding to: ${address.address}');
    _server = await HttpServer.bind(address, 0);
    debugPrint(
        '[LocalServer] Server started on ${address.address}:${_server!.port}');

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      debugPrint(
          '[LocalServer] Request from ${request.connectionInfo?.remoteAddress.address}: $path');
      if (path == '/$_token/download') {
        request.response.headers.contentType =
            ContentType.parse('application/octet-stream');
        request.response.headers
            .add('Content-Disposition', 'attachment; filename="$_fileName"');
        request.response.headers.set('Content-Encoding',
            'identity'); // Disable compression for binary data
        request.response.contentLength = _fileSize!;

        debugPrint('[LocalServer] Starting transfer: $_fileName ($_fileSize bytes)');

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

          debugPrint('[LocalServer] Transfer complete, closing response stream');
          await request.response.close();
          debugPrint(
              '[LocalServer] Response stream closed, waiting for client acknowledgment...');

          // Wait for client to send acknowledgment (with timeout)
          try {
            await _transferCompleteCompleter!.future.timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint(
                    '[LocalServer] ⚠️ Client acknowledgment timeout, shutting down anyway');
              },
            );
            debugPrint('[LocalServer] ✅ Client acknowledged receipt');

            // Small delay to ensure ACK response is sent before server shutdown
            await Future.delayed(const Duration(milliseconds: 50));
          } catch (e) {
            debugPrint('[LocalServer] Error waiting for acknowledgment: $e');
          }

          // One-shot: stop server after successful download
          debugPrint('[LocalServer] Stopping server');
          await stopServer();
          onDone?.call();
        } catch (e) {
          debugPrint('Error serving file: $e');
          await request.response.close();
          await stopServer();
        }
      } else if (path == '/$_token/ack') {
        // Client acknowledgment that file was received successfully
        debugPrint('[LocalServer] Received acknowledgment from client');

        if (_transferCompleteCompleter != null &&
            !_transferCompleteCompleter!.isCompleted) {
          _transferCompleteCompleter!.complete();
        }

        request.response
          ..statusCode = HttpStatus.ok
          ..write('ACK')
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found')
          ..close();
      }
    });

    return _server!.port;
  }

  /// Internal method to start HTTPS server
  static Future<int> _startHttpsServer({
    VoidCallback? onDone,
    Function(int, int)? onProgress,
    String? bindAddress,
  }) async {
    // Load SecurityContext from certificate manager
    final context = await CertificateManager.getSecurityContext();

    // Bind to specific address or all IPv4 interfaces
    final address = bindAddress != null
        ? InternetAddress(bindAddress)
        : InternetAddress.anyIPv4;

    debugPrint('[LocalServer HTTPS] Binding to: ${address.address}');
    _server = await HttpServer.bindSecure(address, 0, context);

    // Optimize TCP settings for HTTPS performance
    _server!.serverHeader =
        null; // Don't send server header (small optimization)

    debugPrint(
        '[LocalServer HTTPS] Server started on ${address.address}:${_server!.port}');

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      debugPrint(
          '[LocalServer HTTPS] Request from ${request.connectionInfo?.remoteAddress.address}: $path');
      if (path == '/$_token/download') {
        request.response.headers.contentType =
            ContentType.parse('application/octet-stream');
        request.response.headers
            .add('Content-Disposition', 'attachment; filename="$_fileName"');
        request.response.headers.set('Content-Encoding',
            'identity'); // Disable compression for binary data
        request.response.contentLength = _fileSize!;

        debugPrint('[LocalServer] Starting transfer: $_fileName ($_fileSize bytes)');

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

          debugPrint('[LocalServer] Transfer complete, closing response stream');
          await request.response.close();
          debugPrint(
              '[LocalServer] Response stream closed, waiting for client acknowledgment...');

          // Wait for client to send acknowledgment (with timeout)
          try {
            await _transferCompleteCompleter!.future.timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint(
                    '[LocalServer] ⚠️ Client acknowledgment timeout, shutting down anyway');
              },
            );
            debugPrint('[LocalServer] ✅ Client acknowledged receipt');

            // Small delay to ensure ACK response is sent before server shutdown
            await Future.delayed(const Duration(milliseconds: 50));
          } catch (e) {
            debugPrint('[LocalServer] Error waiting for acknowledgment: $e');
          }

          // One-shot: stop server after successful download
          debugPrint('[LocalServer] Stopping server');
          await stopServer();
          onDone?.call();
        } catch (e) {
          debugPrint('Error serving file: $e');
          await request.response.close();
          await stopServer();
        }
      } else if (path == '/$_token/ack') {
        // Client acknowledgment that file was received successfully
        debugPrint('[LocalServer] Received acknowledgment from client');

        if (_transferCompleteCompleter != null &&
            !_transferCompleteCompleter!.isCompleted) {
          _transferCompleteCompleter!.complete();
        }

        request.response
          ..statusCode = HttpStatus.ok
          ..write('ACK')
          ..close();
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
    int chunkCount = 0;

    // Use 1MB buffer to maximize throughput and minimize TLS record overhead
    final bufferSize = 1024 * 1024;

    while (offset < total) {
      // Check for cancellation
      if (_cancelController?.isClosed ?? false) {
        throw Exception('Transfer cancelled by user');
      }

      final end = (offset + bufferSize < total) ? offset + bufferSize : total;
      final chunk = data.sublist(offset, end);
      response.add(chunk);

      offset = end;
      onProgress?.call(offset, total);

      // Yield to event loop every 8 buffers (every 8MB) for maximum throughput
      chunkCount++;
      if (chunkCount % 8 == 0) {
        await Future.delayed(Duration.zero);
      }
    }
  }

  /// Stream file in chunks (memory-efficient)
  static Future<void> _streamFileInChunks(
    HttpResponse response,
    String filePath, {
    Function(int, int)? onProgress,
  }) async {
    final file = File(filePath);
    // Read with larger buffer to reduce TLS overhead
    final stream = file.openRead().cast<List<int>>();
    int bytesSent = 0;
    final total = _fileSize!;

    // Buffer chunks to reduce TLS record overhead
    final buffer = BytesBuilder(copy: false);
    const targetBufferSize = 1024 * 1024; // 1MB buffer for maximum throughput
    int writeCount = 0;

    await for (final chunk in stream) {
      // Check for cancellation
      if (_cancelController?.isClosed ?? false) {
        throw Exception('Transfer cancelled by user');
      }

      buffer.add(chunk);

      // Send when buffer is large enough
      if (buffer.length >= targetBufferSize) {
        response.add(buffer.toBytes());
        bytesSent += buffer.length;
        buffer.clear();
        onProgress?.call(bytesSent, total);

        // Yield to event loop every 8 writes (every 8MB) for maximum throughput
        writeCount++;
        if (writeCount % 8 == 0) {
          await Future.delayed(Duration.zero);
        }
      }
    }

    // Send remaining buffered data
    if (buffer.isNotEmpty) {
      response.add(buffer.toBytes());
      bytesSent += buffer.length;
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

    debugPrint('[ReceiveServer] Binding to: ${address.address}');
    _server = await HttpServer.bind(address, 0);
    debugPrint(
        '[ReceiveServer] Server started on ${address.address}:${_server!.port}');

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      debugPrint(
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

          debugPrint(
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

          debugPrint(
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
          debugPrint('[ReceiveServer] Error: $e');
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
