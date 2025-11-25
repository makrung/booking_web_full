import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:image/image.dart' as img; // Accurate image decoding
import 'package:zxing2/qrcode.dart' as zxing; // QRCodeReader
import 'package:zxing2/zxing2.dart' as zcore; // Core luminance/binarizer

class QRCodeReaderService {
  static final ImagePicker _picker = ImagePicker();
  
  // อ่าน QR Code จากรูปภาพที่อัปโหลด
  static Future<String?> readQRFromImage() async {
    try {
      print('🎯 Starting QR Code reading from image...');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 100,
      );
      
      if (image == null) {
        print('❌ No image selected');
        return null;
      }
      
      print('✅ Image selected: ${image.name}');
      
      // สำหรับ Web ใช้ bytes, สำหรับ Mobile ใช้ path
      if (kIsWeb) {
        final Uint8List bytes = await image.readAsBytes();
        print('📊 Image size: ${bytes.length} bytes');
        return await _processImageBytes(bytes);
      } else {
        final File file = File(image.path);
        print('📁 Image path: ${image.path}');
        return await _processImageFile(file);
      }
    } catch (e) {
      print('❌ Error reading QR from image: $e');
      return null;
    }
  }

  /// Public helper: decode directly from image bytes (used by enhanced service)
  static Future<String?> decodeFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    final v = await _decodeWithZXing(bytes);
    return v?.trim().isEmpty == true ? null : v?.trim();
  }
  
  static Future<String?> _processImageBytes(Uint8List bytes) async {
    try {
      print('🔍 Processing image bytes...');
      
      if (bytes.length < 100) {
        print('❌ Image too small: ${bytes.length} bytes');
        return null;
      }
      
      // Only use robust ZXing-based decoding (no heuristic guessing)
      final zxingResult = await _decodeWithZXing(bytes);
      if (zxingResult != null && zxingResult.trim().isNotEmpty) {
        print('✅ QR decoded by ZXing');
        return zxingResult.trim();
      }

      print('❌ No QR Code found');
      return null;
    } catch (e) {
      print('❌ Error processing image bytes: $e');
      return null;
    }
  }
  
  static Future<String?> _processImageFile(File file) async {
    try {
      print('📁 Processing image file...');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        print('📊 File size: ${bytes.length} bytes');
        // Try direct ZXing on file first (can handle some formats better when decoded raw)
        final direct = await _decodeWithZXing(bytes);
        if (direct != null && direct.trim().isNotEmpty) return direct.trim();
        return await _processImageBytes(bytes);
      }
      return null;
    } catch (e) {
      print('❌ Error processing image file: $e');
      return null;
    }
  }

  // Accurate QR decoding using ZXing on decoded image pixels
  static Future<String?> _decodeWithZXing(Uint8List bytes) async {
    try {
      // Decode base image
      final base = img.decodeImage(bytes);
      if (base == null) {
        print('❌ Could not decode image bytes');
        return null;
      }

      // Helpers
      img.Image ensureMinSize(img.Image src, {int minSide = 512, img.Interpolation interpolation = img.Interpolation.nearest}) {
        final ms = math.min(src.width, src.height);
        if (ms >= minSide) return src;
        final scale = (minSide / ms).ceil();
        return img.copyResize(src, width: src.width * scale, height: src.height * scale, interpolation: interpolation);
      }

      List<img.Image> makeMultiScale(img.Image src) {
        final List<img.Image> out = [];
        final s512 = ensureMinSize(src, minSide: 512, interpolation: img.Interpolation.nearest);
        out.add(s512);
        final minSide = math.min(s512.width, s512.height);
        if (minSide < 768) out.add(ensureMinSize(s512, minSide: 768, interpolation: img.Interpolation.nearest));
        if (minSide < 1024) out.add(ensureMinSize(s512, minSide: 1024, interpolation: img.Interpolation.linear));
        return out;
      }

      img.Image toGray(img.Image src) => img.grayscale(src.clone());

      img.Image adjustContrast(img.Image src, {double contrast = 1.3}) {
        try {
          final cp = src.clone();
          return img.adjustColor(cp, contrast: contrast);
        } catch (_) {
          return src;
        }
      }

      img.Image unsharp(img.Image src) {
        try {
          final orig = src.clone();
          final blurred = img.gaussianBlur(src.clone(), radius: 1);
          final out = img.Image.from(src);
          final w = src.width, h = src.height;
          const amount = 0.7;
          for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
              final po = orig.getPixel(x, y);
              final pb = blurred.getPixel(x, y);
              int cr(int o, int b) {
                final v = o + ((o - b) * amount);
                return v < 0 ? 0 : (v > 255 ? 255 : v.toInt());
              }
              final r = cr(po.r.toInt(), pb.r.toInt());
              final g = cr(po.g.toInt(), pb.g.toInt());
              final b = cr(po.b.toInt(), pb.b.toInt());
              out.setPixelRgba(x, y, r, g, b, po.a.toInt());
            }
          }
          return out;
        } catch (_) {
          return img.gaussianBlur(src.clone(), radius: 1);
        }
      }

      img.Image invert(img.Image src) {
        try {
          final cp = src.clone();
          return img.invert(cp);
        } catch (_) {
          return src;
        }
      }

      img.Image otsuBinarize(img.Image gray) {
        final w = gray.width, h = gray.height;
        final hist = List<int>.filled(256, 0);
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final p = gray.getPixel(x, y);
            final v = p.r.toInt();
            hist[v]++;
          }
        }
        final total = w * h;
        double sum = 0;
        for (int i = 0; i < 256; i++) sum += i * hist[i];
        double sumB = 0;
        int wB = 0;
        double varMax = -1;
        int threshold = 127;
        for (int t = 0; t < 256; t++) {
          wB += hist[t];
          if (wB == 0) continue;
          final wF = total - wB;
          if (wF == 0) break;
          sumB += t * hist[t];
          final mB = sumB / wB;
          final mF = (sum - sumB) / wF;
          final varBetween = wB * wF * (mB - mF) * (mB - mF);
          if (varBetween > varMax) {
            varMax = varBetween;
            threshold = t;
          }
        }
        final out = img.Image.from(gray);
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final g = gray.getPixel(x, y).r.toInt();
            final v = g > threshold ? 255 : 0;
            out.setPixelRgba(x, y, v, v, v, 255);
          }
        }
        return out;
      }

      final bool onWeb = kIsWeb;
      final List<img.Image> candidates = [];
      final scales = makeMultiScale(base);
      for (final sc in scales) {
        final gray = toGray(sc);
        final highContrast = adjustContrast(gray, contrast: 1.4);
        final sharp = unsharp(highContrast);
        final bin = otsuBinarize(gray);
        final binInv = invert(bin);

        final baseSet = onWeb
            ? <img.Image>[gray, highContrast, bin, sharp]
            : <img.Image>[sc, gray, highContrast, sharp, bin, binInv];
        candidates.addAll(baseSet);

        final rotateList = onWeb ? <img.Image>[gray, bin] : <img.Image>[gray, sharp, bin];
        for (final v in rotateList) {
          candidates.add(img.copyRotate(v, angle: 90));
          if (!onWeb) candidates.add(img.copyRotate(v, angle: 270));
        }
      }

      // Optional: cap candidates on web
      if (onWeb && candidates.length > 28) {
        candidates.removeRange(28, candidates.length);
      }

      print('🔁 QR decode candidates: ${candidates.length}');

      String? tryDecode(img.Image image) {
        final width = image.width;
        final height = image.height;
        final pixels = Int32List(width * height);
        int idx = 0;
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final p = image.getPixel(x, y);
            final int r = p.r.toInt();
            final int g = p.g.toInt();
            final int b = p.b.toInt();
            final int a = p.a.toInt();
            final int argb = (a << 24) | (r << 16) | (g << 8) | b;
            pixels[idx++] = argb;
          }
        }

        final source = zcore.RGBLuminanceSource(width, height, pixels);
        final bitmap = zcore.BinaryBitmap(zcore.HybridBinarizer(source));
        final reader = zxing.QRCodeReader();
        try {
          final result = reader.decode(bitmap);
          var text = result.text;
          if (text.trim().isEmpty || text.contains('�')) {
            try {
              final raw = (result.rawBytes ?? <int>[]);
              if (raw.isNotEmpty) {
                text = utf8.decode(raw, allowMalformed: true);
              }
            } catch (_) {}
          }
          text = _sanitizeDecodedText(text);
          if (text.isEmpty) return null;
          return text;
        } catch (_) {
          return null;
        }
      }

      final stopwatch = Stopwatch()..start();
      final int budgetMs = onWeb ? 1500 : 4000;
      for (final c in candidates) {
        if (onWeb && stopwatch.elapsedMilliseconds > budgetMs) {
          print('⏱️ Decode budget exceeded on web, stopping.');
          break;
        }
        final v = tryDecode(c);
        if (v != null) return v;
      }

      return null;
    } catch (e) {
      print('⚠️ ZXing decode failed: $e');
      return null;
    }
  }

  // Remove invisible and control characters; keep Thai and common ASCII symbols
  static String _sanitizeDecodedText(String input) {
    String s = input;
    // Replace control chars except new lines and tabs
    s = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    // Trim and collapse spaces
    s = s.trim();
    // If too many replacement chars, clear
    final replCount = '�'.allMatches(s).length;
    if (replCount > 0 && replCount >= (s.length / 4)) {
      return '';
    }
    return s;
  }

  
  
  // ตรวจสอบความถูกต้องของ QR Code
  static bool isValidQRCode(String qrData) {
    try {
      final decoded = json.decode(qrData);
      
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('type') &&
          decoded.containsKey('court_id') &&
          decoded.containsKey('court_name') &&
          decoded['type'] == 'court_verification') {
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}
