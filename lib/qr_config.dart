import 'dart:convert';

/// Type of content to encode in the QR code
enum QrType {
  metadata, // Original JSON format with author, URL, and timestamp
  url, // Direct website redirect URL
  vcard, // vCard contact information sharing
}

/// Configuration for QR code watermarking
class QrWatermarkConfig {
  const QrWatermarkConfig({
    required this.timestamp,
    this.type = QrType.metadata,
    this.author,
    this.url,
    this.vCardFirstName,
    this.vCardLastName,
    this.vCardPhone,
    this.vCardEmail,
    this.vCardOrg,
    this.includeTimestamp = true,
    this.includeAuthor = true,
    this.includeUrl = true,
    this.position = QrPosition.bottomRight,
    this.size = 100.0,
    this.opacity = 0.8,
    this.visibleQr = true,
    this.invisibleQr = false,
  });

  final QrType type;
  final DateTime timestamp;

  // For Metadata type
  final String? author;
  final String? url;
  final bool includeTimestamp;
  final bool includeAuthor;
  final bool includeUrl;

  // For vCard type
  final String? vCardFirstName;
  final String? vCardLastName;
  final String? vCardPhone;
  final String? vCardEmail;
  final String? vCardOrg;

  // For visible QR codes
  final QrPosition position;
  final double size; // 50-200 pixels
  final double opacity; // 0.0-1.0

  // Mode selection
  final bool visibleQr;
  final bool invisibleQr;

  /// Converts metadata to string for QR code content based on selected type
  String toQrString() {
    switch (type) {
      case QrType.url:
        return url ?? '';

      case QrType.vcard:
        final buffer = StringBuffer();
        buffer.writeln('BEGIN:VCARD');
        buffer.writeln('VERSION:3.0');
        buffer.writeln('N:${vCardLastName ?? ''};${vCardFirstName ?? ''};;;');
        buffer.writeln(
            'FN:${vCardFirstName ?? ''} ${vCardLastName ?? ''}'.trim());
        if (vCardOrg != null && vCardOrg!.isNotEmpty) {
          buffer.writeln('ORG:$vCardOrg');
        }
        if (vCardPhone != null && vCardPhone!.isNotEmpty) {
          buffer.writeln('TEL;TYPE=CELL:$vCardPhone');
        }
        if (vCardEmail != null && vCardEmail!.isNotEmpty) {
          buffer.writeln('EMAIL;TYPE=INTERNET:$vCardEmail');
        }
        buffer.writeln('END:VCARD');
        return buffer.toString();

      default:
        final data = <String, dynamic>{};
        if (includeAuthor && author != null && author!.isNotEmpty) {
          data['author'] = author;
        }
        if (includeUrl && url != null && url!.isNotEmpty) {
          data['url'] = url;
        }
        if (includeTimestamp) {
          data['timestamp'] = timestamp.toIso8601String();
        }
        data['app'] = 'SecureMark';
        data['version'] = '1.0';
        return jsonEncode(data);
    }
  }

  /// Creates a copy with updated values
  QrWatermarkConfig copyWith({
    QrType? type,
    String? author,
    String? url,
    String? vCardFirstName,
    String? vCardLastName,
    String? vCardPhone,
    String? vCardEmail,
    String? vCardOrg,
    DateTime? timestamp,
    bool? includeTimestamp,
    bool? includeAuthor,
    bool? includeUrl,
    QrPosition? position,
    double? size,
    double? opacity,
    bool? visibleQr,
    bool? invisibleQr,
  }) {
    return QrWatermarkConfig(
      type: type ?? this.type,
      author: author ?? this.author,
      url: url ?? this.url,
      vCardFirstName: vCardFirstName ?? this.vCardFirstName,
      vCardLastName: vCardLastName ?? this.vCardLastName,
      vCardPhone: vCardPhone ?? this.vCardPhone,
      vCardEmail: vCardEmail ?? this.vCardEmail,
      vCardOrg: vCardOrg ?? this.vCardOrg,
      timestamp: timestamp ?? this.timestamp,
      includeTimestamp: includeTimestamp ?? this.includeTimestamp,
      includeAuthor: includeAuthor ?? this.includeAuthor,
      includeUrl: includeUrl ?? this.includeUrl,
      position: position ?? this.position,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      visibleQr: visibleQr ?? this.visibleQr,
      invisibleQr: invisibleQr ?? this.invisibleQr,
    );
  }
}

/// Position for visible QR codes on the image
enum QrPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}
