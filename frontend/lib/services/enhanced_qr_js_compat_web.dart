import 'dart:convert';
import 'dart:typed_data';
import 'package:js/js_util.dart' as js_util;
import 'package:web/web.dart' as web;

Future<String?> decodeQrViaJs(Uint8List bytes) async {
  try {
    final b64 = base64Encode(bytes);
    final func = js_util.getProperty(web.window, 'qrDecodeFromBase64');
    if (func == null) return null;
    final result = await js_util.promiseToFuture(js_util.callMethod(func, 'call', [web.window, b64]));
    if (result == null) return null;
    final text = result.toString().trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}
