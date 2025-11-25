import 'package:shared_preferences/shared_preferences.dart';
import 'content_service.dart';
import 'package:flutter/foundation.dart';

class SettingsService {
  static const String _qrUploadModeKey = 'qr_upload_mode_enabled';
  static const String _adminBookingModeKey = 'admin_booking_mode_enabled';
  static const String _testModeKey = 'test_mode_enabled'; // โหมดทดสอบสำหรับทุกคน
  // Notifier so UI can react to changes immediately without manual reopen
  static final ValueNotifier<bool> testModeNotifier = ValueNotifier<bool>(false);
  
  // ดึงสถานะการเปิด/ปิดโหมดอัปโหลด QR Code
  static Future<bool> isQRUploadModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_qrUploadModeKey) ?? false; // Default: ปิด (ใช้กล้อง)
  }
  
  // เปิด/ปิดโหมดอัปโหลด QR Code
  static Future<void> setQRUploadMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_qrUploadModeKey, enabled);
  }
  
  // Toggle โหมด
  static Future<bool> toggleQRUploadMode() async {
    final current = await isQRUploadModeEnabled();
    await setQRUploadMode(!current);
    return !current;
  }

  // ดึงสถานะการเปิด/ปิดโหมดจองสำหรับ admin (จองได้ทุกเวลา)
  static Future<bool> isAdminBookingModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adminBookingModeKey) ?? false; // Default: ปิด
  }
  
  // เปิด/ปิดโหมดจองสำหรับ admin
  static Future<void> setAdminBookingMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adminBookingModeKey, enabled);
  }
  
  // Toggle โหมดจองสำหรับ admin
  static Future<bool> toggleAdminBookingMode() async {
    final current = await isAdminBookingModeEnabled();
    await setAdminBookingMode(!current);
    return !current;
  }

  // ===== โหมดทดสอบสำหรับทุกคน (ยกเลิกข้อจำกัดเวลาและวันที่) =====
  
  // ดึงสถานะโหมดทดสอบ (ทุกคนจองได้ทุกเวลา)
  static Future<bool> isTestModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // 1) local pref as fallback
    final localVal = prefs.getBool(_testModeKey) ?? false;
    // 2) attempt to read server-side content value (so admin toggle on server affects all clients)
    try {
      final serverRaw = await ContentService.getContent('test_mode_enabled');
      if (serverRaw != null) {
        final s = serverRaw.toString().toLowerCase();
        final serverVal = (s == '1' || s == 'true');
        try { testModeNotifier.value = serverVal; } catch (_) {}
        // keep local pref in sync for this device
        await prefs.setBool(_testModeKey, serverVal);
        return serverVal;
      }
    } catch (_) {}

    try { testModeNotifier.value = localVal; } catch (_) {}
    return localVal;
  }
  
  // เปิด/ปิดโหมดทดสอบ (ทุกคนจองได้ทุกเวลา)
  static Future<void> setTestMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testModeKey, enabled);
    try { testModeNotifier.value = enabled; } catch (_) {}
    // Also persist to server content so other clients pick it up
    try {
      await ContentService.setContent('test_mode_enabled', enabled ? '1' : '0');
    } catch (_) {}
  }
  
  // Toggle โหมดทดสอบ
  static Future<bool> toggleTestMode() async {
    final current = await isTestModeEnabled();
    await setTestMode(!current);
    return !current;
  }
}
