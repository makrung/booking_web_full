import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/base_service.dart';
import '../config/app_config.dart';

class ActivityRequestsService extends BaseService {
  static Future<List<dynamic>> listAll() async {
    final headers = await BaseService.getHeaders();
    final resp = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/activity-requests'), headers: headers);
    final data = BaseService.parseJsonResponse(resp);
    if (resp.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['activityRequests'] ?? []);
    }
    throw Exception(data['message'] ?? data['error'] ?? 'โหลดคำขอกิจกรรมล้มเหลว');
  }

  // Fetch activity requests for a given court (non-admin endpoint)
  static Future<List<dynamic>> forCourt(String courtId) async {
    final headers = await BaseService.getHeaders();
    final resp = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/activity-requests/for-court/$courtId'), headers: headers);
    final data = BaseService.parseJsonResponse(resp);
    if (resp.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['activityRequests'] ?? []);
    }
    throw Exception(data['message'] ?? data['error'] ?? 'โหลดคำขอกิจกรรมล้มเหลว');
  }

  static Future<Map<String, dynamic>> setStatus({required String id, required String status, String? rejectionReason}) async {
    final headers = await BaseService.getHeaders();
    final resp = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/activity-requests/$id/status'),
      headers: headers,
      body: json.encode({'status': status, if (rejectionReason != null) 'rejectionReason': rejectionReason}),
    );
    return BaseService.parseJsonResponse(resp);
  }

  static Future<List<dynamic>> myRequests() async {
    final headers = await BaseService.getHeaders();
    final resp = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/activity-requests/my'), headers: headers);
    final data = BaseService.parseJsonResponse(resp);
    if (resp.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['requests'] ?? []);
    }
    throw Exception(data['message'] ?? data['error'] ?? 'โหลดคำขอกิจกรรมของฉันล้มเหลว');
  }
}
