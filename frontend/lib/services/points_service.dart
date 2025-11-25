import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
class PointsService {
	static const String baseUrl = 'http://localhost:3000/api';

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
	// User: request points
	static Future<Map<String, dynamic>> requestPoints({required int points, String? reason}) async {
		final headers = await _getAuthHeaders();
		final resp = await http.post(
			Uri.parse('$baseUrl/points/requests'),
			headers: headers,
			body: json.encode({'requestedPoints': points, 'reason': reason ?? ''}),
		);
		return json.decode(resp.body);
	}
	// User: my requests
	static Future<List<dynamic>> myRequests() async {
		final headers = await _getAuthHeaders();
		final resp = await http.get(Uri.parse('$baseUrl/points/requests'), headers: headers);
		final data = json.decode(resp.body);
		if (data['success'] == true) return List<dynamic>.from(data['requests'] ?? []);
		throw Exception(data['error'] ?? 'โหลดคำขอล้มเหลว');
	}
	// Admin: list all requests
	static Future<List<dynamic>> listAllRequests() async {
		final headers = await _getAuthHeaders();
		final resp = await http.get(Uri.parse('$baseUrl/admin/points/requests'), headers: headers);
		final data = json.decode(resp.body);
		if (data['success'] == true) return List<dynamic>.from(data['requests'] ?? []);
		throw Exception(data['error'] ?? 'โหลดคำขอล้มเหลว');
	}

	// Admin: decision
	static Future<Map<String, dynamic>> decideRequest({required String id, required String decision, int? points, String? message}) async {
		final headers = await _getAuthHeaders();
		final resp = await http.post(
			Uri.parse('$baseUrl/admin/points/requests/$id/decision'),
			headers: headers,
			body: json.encode({'decision': decision, 'points': points, 'message': message}),
		);
		return json.decode(resp.body);
	}

	// Admin: stats for requests
	static Future<Map<String, dynamic>> adminRequestsStats() async {
		final headers = await _getAuthHeaders();
		final resp = await http.get(Uri.parse('$baseUrl/admin/points/requests/stats'), headers: headers);
		return json.decode(resp.body);
	}

	// Admin: edit pending request
	static Future<Map<String, dynamic>> editRequest({required String id, int? requestedPoints, String? reason}) async {
		final headers = await _getAuthHeaders();
		final resp = await http.patch(
			Uri.parse('$baseUrl/admin/points/requests/$id'),
			headers: headers,
			body: json.encode({ if (requestedPoints != null) 'requestedPoints': requestedPoints, if (reason != null) 'reason': reason }),
		);
		return json.decode(resp.body);
	}

	// Admin: delete request
	static Future<Map<String, dynamic>> deleteRequest(String id) async {
		final headers = await _getAuthHeaders();
		final resp = await http.delete(Uri.parse('$baseUrl/admin/points/requests/$id'), headers: headers);
		return json.decode(resp.body);
	}

	// Admin: change status (pending/approved/denied) with safe point adjustment
	static Future<Map<String, dynamic>> changeStatus({required String id, required String status, int? points, String? message}) async {
		final headers = await _getAuthHeaders();
		final resp = await http.patch(
			Uri.parse('$baseUrl/admin/points/requests/$id/status'),
			headers: headers,
			body: json.encode({'status': status, if (points != null) 'points': points, if (message != null) 'message': message}),
		);
		return json.decode(resp.body);
	}

	// Admin: mark all pending requests as read
	static Future<Map<String, dynamic>> markAllRequestsRead() async {
		final headers = await _getAuthHeaders();
		final resp = await http.post(Uri.parse('$baseUrl/admin/points/requests/mark-read'), headers: headers);
		return json.decode(resp.body);
	}

	// User: inbox messages
	static Future<List<dynamic>> inboxMessages() async {
		final headers = await _getAuthHeaders();
		final resp = await http.get(Uri.parse('$baseUrl/messages'), headers: headers);
		final data = json.decode(resp.body);
		if (data['success'] == true) return List<dynamic>.from(data['messages'] ?? []);
		throw Exception(data['error'] ?? 'โหลดข้อความล้มเหลว');
	}

	static Future<void> markMessageRead(String id) async {
		final headers = await _getAuthHeaders();
		await http.post(Uri.parse('$baseUrl/messages/$id/read'), headers: headers);
	}

	static Future<int> markAllMessagesRead() async {
		final headers = await _getAuthHeaders();
		final resp = await http.post(Uri.parse('$baseUrl/messages/mark-all-read'), headers: headers);
		final data = json.decode(resp.body);
		if (data is Map && data['success'] == true) return (data['marked'] ?? 0) as int? ?? 0;
		return 0;
	}

	// Unread count for inbox badge
	static Future<int> unreadMessagesCount() async {
		final headers = await _getAuthHeaders();
		final resp = await http.get(Uri.parse('$baseUrl/messages/unread-count'), headers: headers);
		final data = json.decode(resp.body);
		if (data is Map && data['success'] == true) {
			final n = data['unread'];
			if (n is int) return n;
			if (n is String) return int.tryParse(n) ?? 0;
		}
		return 0;
	}
}
