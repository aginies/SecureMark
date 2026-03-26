import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

class LocalServerManager {
  static HttpServer? _server;
  static Uint8List? _fileBytes;
  static String? _fileName;
  static String? _token;

  static bool get isRunning => _server != null;

  static Future<List<String>> getLocalIps() async {
    final List<String> ips = [];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          ips.add(addr.address);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error getting local IPs: $e');
    }
    return ips;
  }

  static Future<int> startServer(Uint8List bytes, String name,
      {VoidCallback? onDone}) async {
    if (_server != null) {
      await stopServer();
    }

    _fileBytes = bytes;
    _fileName = name;
    _token = _generateRandomToken();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      if (path == '/$_token/download') {
        request.response.headers.contentType =
            ContentType.parse('application/octet-stream');
        request.response.headers
            .add('Content-Disposition', 'attachment; filename="$_fileName"');
        request.response.add(_fileBytes!);
        await request.response.close();

        // One-shot: stop server after successful download
        await stopServer();
        onDone?.call();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found')
          ..close();
      }
    });

    return _server!.port;
  }

  static Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    _fileBytes = null;
    _fileName = null;
    _token = null;
  }

  static String? get token => _token;

  static Future<int> startReceiveServer(
      Function(Uint8List, String, String) onFileReceived,
      {VoidCallback? onDone}) async {
    if (_server != null) {
      await stopServer();
    }

    _token = _generateRandomToken();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);

    _server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      if (request.method == 'POST' && path == '/$_token/upload') {
        try {
          final fileName =
              request.headers.value('x-file-name') ?? 'uploaded_file';

          final BytesBuilder builder = BytesBuilder();
          await for (final chunk in request) {
            builder.add(chunk);
          }

          final bytes = builder.toBytes();
          onFileReceived(bytes, fileName,
              request.connectionInfo?.remoteAddress.address ?? 'unknown');

          request.response.statusCode = HttpStatus.ok;
          request.response.write('OK');
          await request.response.close();

          // One-shot: stop server after successful upload
          await stopServer();
          onDone?.call();
        } catch (e) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Error: $e')
            ..close();
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

  static String _generateRandomToken() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }
}
