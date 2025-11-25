import 'dart:typed_data';

Future<String?> decodeQrViaJs(Uint8List bytes) async {
  // Non-web platforms: no JS decoder
  return null;
}
