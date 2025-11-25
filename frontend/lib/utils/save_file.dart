import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html; // web
import 'dart:io' as io; // non-web
import 'package:path_provider/path_provider.dart';

class SaveFileHelper {
  static Future<void> saveBytes({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return;
    }

    // Non-web: write file to Downloads/Documents
    io.Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();
    final fullPath = io.Platform.isWindows
        ? '${dir.path}\\$fileName'
        : '${dir.path}/$fileName';
    final f = io.File(fullPath);
    await f.writeAsBytes(bytes, flush: true);
  }
}
