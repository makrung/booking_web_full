import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Original ActivityService
/// Maintains backward compatibility with existing code
class ActivityService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ส่งคำขอจองสำหรับกิจกรรม
  static Future<Map<String, dynamic>> submitActivityRequest({
    required String responsiblePersonName,
    required String responsiblePersonId,
    required String responsiblePersonPhone,
    required String responsiblePersonEmail,
    required String activityName,
    required String activityDescription,
    required String activityDate,
    required String timeSlot,
    required String courtId,
    required String organizationDocument,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/activity-requests/submit'),
        headers: headers,
        body: json.encode({
          'responsiblePersonName': responsiblePersonName,
          'responsiblePersonId': responsiblePersonId,
          'responsiblePersonPhone': responsiblePersonPhone,
          'responsiblePersonEmail': responsiblePersonEmail,
          'activityName': activityName,
          'activityDescription': activityDescription,
          'activityDate': activityDate,
          'timeSlot': timeSlot,
          'courtId': courtId,
          'organizationDocument': organizationDocument,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to submit request');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ดึงรายการคำขอทั้งหมด (สำหรับ admin)
  static Future<Map<String, dynamic>> getAllRequests({String? status}) async {
    try {
      final headers = await _getAuthHeaders();
      String url = '$baseUrl/activity-requests/all';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load requests');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ดึงคำขอของผู้ใช้
  static Future<Map<String, dynamic>> getUserRequests() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/activity-requests/my-requests'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load user requests');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // อนุมัติคำขอ (admin)
  static Future<Map<String, dynamic>> approveRequest(String requestId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/activity-requests/$requestId/approve'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to approve request');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ปฏิเสธคำขอ (admin)
  static Future<Map<String, dynamic>> rejectRequest({
    required String requestId,
    required String reason,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/activity-requests/$requestId/reject'),
        headers: headers,
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to reject request');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ยกเลิกคำขอ (ผู้ใช้)
  static Future<Map<String, dynamic>> cancelRequest(String requestId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/activity-requests/$requestId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to cancel request');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ดึงข้อมูลคำขอแต่ละรายการ
  static Future<Map<String, dynamic>> getRequestById(String requestId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/activity-requests/$requestId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load request');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Alias for getAllRequests (backward compatibility)
  static Future<Map<String, dynamic>> getActivityRequests({String? status}) async {
    return getAllRequests(status: status);
  }

  // Alias for approveRequest (backward compatibility)
  static Future<Map<String, dynamic>> approveActivityRequest(String requestId) async {
    return approveRequest(requestId);
  }

  // Alias for rejectRequest (backward compatibility)
  static Future<Map<String, dynamic>> rejectActivityRequest(
    String requestId, {
    required String rejectionReason,
  }) async {
    return rejectRequest(requestId: requestId, reason: rejectionReason);
  }
}
