import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'qr_reader_service.dart' as dartQR; // fallback ZXing pipeline
import 'enhanced_qr_js_compat.dart';

/// High-accuracy QR Reader with platform-aware backends
/// - Web: uses jsQR via a tiny JS bridge for fast and robust decoding
/// - Mobile/Desktop: uses existing ZXing pipeline from qr_reader_service.dart
class EnhancedQRReaderService {
	static final ImagePicker _picker = ImagePicker();

	/// Read a QR code from an image (gallery picker UI inside)
	static Future<String?> readFromImagePicker() async {
		final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 100);
		if (image == null) return null;
		final Uint8List bytes = await image.readAsBytes();
		return decodeFromBytes(bytes);
	}

	/// Decode QR text from raw image bytes
	static Future<String?> decodeFromBytes(Uint8List bytes) async {
		if (kIsWeb) {
			final v = await _decodeOnWeb(bytes);
			if (v != null && v.trim().isNotEmpty) return v.trim();
			// Fallback to Dart ZXing if jsQR fails
			final fb = await dartQR.QRCodeReaderService.decodeFromBytes(bytes);
			return fb?.trim();
		} else {
			// Mobile/Desktop: use Dart ZXing pipeline
			final fb = await dartQR.QRCodeReaderService.decodeFromBytes(bytes);
			return fb?.trim();
		}
	}

	/// Web-only: decode using jsQR bridge for high accuracy and speed
		static Future<String?> _decodeOnWeb(Uint8List bytes) async {
			final res = await decodeQrViaJs(bytes);
			if (res == null) return null;
			final text = res.trim();
			return text.isEmpty ? null : _sanitize(text);
		}

	static String _sanitize(String s) {
			var t = s
					// Remove control chars
					.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
					// Remove BOM and NBSP
					.replaceAll('\uFEFF', '')
					.replaceAll('\u00A0', ' ')
					// Collapse any unicode whitespace to single spaces
					.replaceAll(RegExp(r'\s+'), ' ')
					.trim();
			// Strip surrounding quotes if the whole string is quoted
			if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
				t = t.substring(1, t.length - 1).trim();
			}
		final repl = '�'.allMatches(t).length;
		if (repl > 0 && repl >= (t.length / 4)) return '';
		return t;
	}
}

