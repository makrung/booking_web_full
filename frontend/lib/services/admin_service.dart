import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AdminService {
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

  // Dashboard
  static Future<Map<String, dynamic>> getDashboard() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/dashboard'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Backend returns { success: true, data: {...} }
        return {
          'success': data['success'] ?? true,
          'data': data['data'] ?? data, // Handle both formats
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      print('AdminService getDashboard error: $e');
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $e',
      };
    }
  }

  // Analytics aggregates
  static Future<Map<String, dynamic>> getAnalytics({required String period, int? year, int? month, String? date}) async {
    try {
      final headers = await _getAuthHeaders();
      final qp = <String, String>{ 'period': period };
      if (year != null) qp['year'] = year.toString();
      if (month != null) qp['month'] = month.toString();
      if (date != null) qp['date'] = date;
      final uri = Uri.parse('$baseUrl/admin/analytics').replace(queryParameters: qp);
      final resp = await http.get(uri, headers: headers);
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'data': data['data'] };
      }
      return { 'success': false, 'error': data['error'] ?? 'โหลดสรุปไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้' };
    }
  }

  // Users Management
  static Future<Map<String, dynamic>> getUsers() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Backend returns { success: true, data: [...] }
        return {
          'success': data['success'] ?? true,
          'data': data['data'] ?? data, // Handle both formats
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      print('AdminService getUsers error: $e');
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $e',
      };
    }
  }

  // Update user (admin)
  static Future<Map<String, dynamic>> updateUser(String userId, Map<String, dynamic> payload) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.put(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: headers,
        body: json.encode(payload),
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'user': data['user'], 'message': data['message'] ?? 'อัปเดตผู้ใช้สำเร็จ' };
      }
      return { 'success': false, 'error': data['error'] ?? 'อัปเดตผู้ใช้ไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  // Update a user's extra daily rights (admin)
  static Future<Map<String, dynamic>> setExtraDailyRights(String userId, int extra) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/extra-rights'),
        headers: headers,
        body: json.encode({ 'extraDailyRights': extra }),
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'extraDailyRights': data['extraDailyRights'], 'message': data['message'] };
      }
      return { 'success': false, 'error': data['error'] ?? 'อัปเดตสิทธิ์พิเศษไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  // Admin edit booking
  static Future<Map<String, dynamic>> editBooking(String bookingId, Map<String, dynamic> payload) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.put(
        Uri.parse('$baseUrl/admin/bookings/$bookingId'),
        headers: headers,
        body: json.encode(payload),
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'booking': data['booking'], 'message': data['message'] };
      }
      return { 'success': false, 'error': data['error'] ?? 'แก้ไขการจองไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  // Admin delete booking
  static Future<Map<String, dynamic>> deleteBooking(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.delete(
        Uri.parse('$baseUrl/admin/bookings/$bookingId'),
        headers: headers,
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'message': data['message'] ?? 'ลบการจองสำเร็จ' };
      }
      return { 'success': false, 'error': data['error'] ?? 'ลบการจองไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  // Admin edit activity request details
  static Future<Map<String, dynamic>> editActivityRequest(String id, Map<String, dynamic> payload) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.patch(
        Uri.parse('$baseUrl/activity-requests/$id'),
        headers: headers,
        body: json.encode(payload),
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'activityRequest': data['activityRequest'] };
      }
      return { 'success': false, 'error': data['message'] ?? data['error'] ?? 'แก้ไขคำขอกิจกรรมไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  // Admin delete activity request
  static Future<Map<String, dynamic>> deleteActivityRequest(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.delete(
        Uri.parse('$baseUrl/activity-requests/$id'),
        headers: headers,
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'message': data['message'] ?? 'ลบคำขอกิจกรรมสำเร็จ' };
      }
      return { 'success': false, 'error': data['message'] ?? data['error'] ?? 'ลบคำขอกิจกรรมไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  // Admin get booking rights breakdown for a user
  static Future<Map<String, dynamic>> getUserCodeStatus(String userId) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.get(
        Uri.parse('$baseUrl/admin/users/$userId/code-status'),
        headers: headers,
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return data;
      }
      return { 'success': false, 'error': data['error'] ?? 'โหลดสรุปสิทธิ์ไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  // Block/unblock user requests/messages
  static Future<Map<String, dynamic>> setUserBlock(String userId, {bool? requestBlocked, bool? messagesBlocked, String? reason}) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/block'),
        headers: headers,
        body: json.encode({
          if (requestBlocked != null) 'requestBlocked': requestBlocked,
          if (messagesBlocked != null) 'messagesBlocked': messagesBlocked,
          if (reason != null) 'reason': reason,
        }),
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'message': data['message'] ?? 'อัปเดตการบล็อคสำเร็จ' };
      }
      return { 'success': false, 'error': data['error'] ?? 'อัปเดตการบล็อคไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  // Delete (soft) user
  static Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.delete(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: headers,
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'message': data['message'] ?? 'ลบผู้ใช้สำเร็จ' };
      }
      return { 'success': false, 'error': data['error'] ?? 'ลบผู้ใช้ไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  // ===== Deleted Users Management =====
  static Future<Map<String, dynamic>> getDeletedUsers() async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.get(
        Uri.parse('$baseUrl/admin/deleted-users'),
        headers: headers,
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'data': data['data'] ?? [] };
      }
      return { 'success': false, 'error': data['error'] ?? 'ไม่สามารถโหลดผู้ใช้ที่ถูกลบได้' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  static Future<Map<String, dynamic>> restoreDeletedUser(String userId) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.post(
        Uri.parse('$baseUrl/admin/deleted-users/$userId/restore'),
        headers: headers,
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'message': data['message'] ?? 'กู้คืนผู้ใช้สำเร็จ' };
      }
      return { 'success': false, 'error': data['error'] ?? 'กู้คืนผู้ใช้ไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  static Future<Map<String, dynamic>> purgeDeletedUser(String userId) async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.delete(
        Uri.parse('$baseUrl/admin/deleted-users/$userId'),
        headers: headers,
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'message': data['message'] ?? 'ลบถาวรผู้ใช้สำเร็จ' };
      }
      return { 'success': false, 'error': data['error'] ?? 'ลบถาวรผู้ใช้ไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  static Future<Map<String, dynamic>> purgeAllDeletedUsers() async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.delete(
        Uri.parse('$baseUrl/admin/deleted-users'),
        headers: headers,
      );
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && (data['success'] ?? true)) {
        return { 'success': true, 'message': data['message'] ?? 'ลบผู้ใช้ที่ถูกลบทั้งหมดแล้ว' };
      }
      return { 'success': false, 'error': data['error'] ?? 'ลบทั้งหมดไม่สำเร็จ' };
    } catch (e) {
      return { 'success': false, 'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้' };
    }
  }

  static Future<Map<String, dynamic>> toggleUserStatus(String userId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/toggle-status'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'อัปเดตสถานะผู้ใช้สำเร็จ',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้',
      };
    }
  }

  // Bookings Management
  static Future<Map<String, dynamic>> getBookings() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/bookings'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Backend returns { success: true, data: [...] }
        return {
          'success': data['success'] ?? true,
          'data': data['data'] ?? data, // Handle both formats
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      print('AdminService getBookings error: $e');
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> updateBookingStatus(
      String bookingId, String status) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/bookings/$bookingId/status'),
        headers: headers,
        body: json.encode({'status': status}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'อัปเดตสถานะการจองสำเร็จ',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้',
      };
    }
  }

  // Courts Management
  static Future<Map<String, dynamic>> getCourts() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/courts'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Backend returns { success: true, data: [...] }
        return {
          'success': data['success'] ?? true,
          'data': data['data'] ?? data, // Handle both formats
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      print('AdminService getCourts error: $e');
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> createCourt(Map<String, dynamic> courtData) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/courts'),
        headers: headers,
        body: json.encode(courtData),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'สร้างสนามสำเร็จ',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้',
      };
    }
  }

  static Future<Map<String, dynamic>> updateCourt(
      String courtId, Map<String, dynamic> courtData) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/admin/courts/$courtId'),
        headers: headers,
        body: json.encode(courtData),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'อัปเดตสนามสำเร็จ',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteCourt(String courtId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/courts/$courtId'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'ลบสนามสำเร็จ',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้',
      };
    }
  }

  // Points Management
  static Future<Map<String, dynamic>> updateUserPoints(
    String userId, 
    int points, 
    String action, 
    String reason
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/points'),
        headers: headers,
        body: json.encode({
          'points': points,
          'action': action, // 'add', 'subtract', 'set'
          'reason': reason,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'อัปเดตคะแนนสำเร็จ',
          'pointsBefore': data['pointsBefore'],
          'pointsAfter': data['pointsAfter'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyBookingUsage(
    String bookingId, 
    bool actuallyUsed, 
    {int pointsToDeduct = 10}
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/bookings/$bookingId/verify-usage'),
        headers: headers,
        body: json.encode({
          'actuallyUsed': actuallyUsed,
          'pointsToDeduct': pointsToDeduct,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'ยืนยันการใช้สนามสำเร็จ',
          'actuallyUsed': data['actuallyUsed'],
          'pointsDeducted': data['pointsDeducted'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้',
      };
    }
  }

  // Activity Requests - แค่ return empty data เพื่อไม่ให้ error
  static Future<Map<String, dynamic>> getActivityRequests() async {
    try {
      // ปัจจุบันยังไม่มี API สำหรับ activity requests
      // ส่งคืนข้อมูลว่างเพื่อไม่ให้ error
      return {
        'success': true,
        'data': [],
        'message': 'ยังไม่มีข้อมูลคำขอกิจกรรม',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'ไม่สามารถโหลดข้อมูลคำขอกิจกรรมได้',
        'data': [],
      };
    }
  }
}
