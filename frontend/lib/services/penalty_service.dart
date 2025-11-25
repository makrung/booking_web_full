import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class PenaltyService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ตรวจสอบการจองที่หมดเวลาและหักคะแนน
  static Future<Map<String, dynamic>> checkAndApplyPenalties() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/penalties/check-expired-bookings'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'expiredBookings': data['expiredBookings'] ?? [],
          'totalPenaltyPoints': data['totalPenaltyPoints'] ?? 0,
          'message': data['message'] ?? '',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดในการตรวจสอบคะแนนโทษ',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $e',
      };
    }
  }

  // ดึงประวัติคะแนนโทษ
  static Future<Map<String, dynamic>> getPenaltyHistory() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/penalties/history'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'penalties': data['penalties'] ?? [],
          // Backend returns totalPenaltyPoints; map it to totalPoints for UI compatibility
          'totalPoints': (data['totalPenaltyPoints'] ?? data['totalPoints'] ?? 0),
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูล',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $e',
      };
    }
  }

  // ดึงข้อมูลคะแนนปัจจุบันของผู้ใช้
  static Future<Map<String, dynamic>> getCurrentPoints() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/user/points'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'points': (data['points'] ?? 0),
          'canBook': data['canBook'] ?? true,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูลคะแนน',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $e',
      };
    }
  }

  // แจ้งเตือนการจองที่ใกล้หมดเวลา
  static Future<Map<String, dynamic>> getUpcomingBookings() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/upcoming'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'upcomingBookings': data['upcomingBookings'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูล',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $e',
      };
    }
  }

  // คำนวณคะแนนโทษ
  // หมายเหตุ: การคำนวณคะแนนโทษถูกกำหนดโดยฝั่งเซิร์ฟเวอร์ตามค่าตั้งค่า (settings)
  // ฟังก์ชันเดิมสำหรับคำนวณในฝั่งแอปถูกลบเพื่อป้องกันความไม่สอดคล้องของค่า
  // โปรดใช้ข้อมูลจาก API เท่านั้น (เช่น penalties/check-expired-bookings หรือ penalties/history)

  // แสดงข้อความแจ้งเตือนคะแนนโทษ
  static String getPenaltyMessage(int penaltyPoints, String reason) {
    return 'คุณถูกหักคะแนน $penaltyPoints คะแนน เนื่องจาก$reason';
  }
}
