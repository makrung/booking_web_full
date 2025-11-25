import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Base service class for all API services
/// Provides common functionality like token management and HTTP requests
/// This eliminates code duplication across services
abstract class BaseService {
  /// Get authentication token from storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.tokenKey);
  }

  /// Save authentication token to storage
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.tokenKey, token);
  }

  /// Remove authentication token from storage
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.tokenKey);
  }

  /// Get headers with authentication token
  static Future<Map<String, String>> getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Generic GET request
  static Future<http.Response> get(
    String endpoint, {
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    final headers = await getHeaders(includeAuth: includeAuth);
    final uri = Uri.parse(endpoint);
    
    return await http
        .get(uri, headers: headers)
        .timeout(timeout ?? AppConfig.apiTimeout);
  }

  /// Generic POST request
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    final headers = await getHeaders(includeAuth: includeAuth);
    final uri = Uri.parse(endpoint);
    
    return await http
        .post(uri, headers: headers, body: json.encode(body))
        .timeout(timeout ?? AppConfig.apiTimeout);
  }

  /// Generic PUT request
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    final headers = await getHeaders(includeAuth: includeAuth);
    final uri = Uri.parse(endpoint);
    
    return await http
        .put(uri, headers: headers, body: json.encode(body))
        .timeout(timeout ?? AppConfig.apiTimeout);
  }

  /// Generic DELETE request
  static Future<http.Response> delete(
    String endpoint, {
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    final headers = await getHeaders(includeAuth: includeAuth);
    final uri = Uri.parse(endpoint);
    
    return await http
        .delete(uri, headers: headers)
        .timeout(timeout ?? AppConfig.apiTimeout);
  }

  /// Generic PATCH request
  static Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    final headers = await getHeaders(includeAuth: includeAuth);
    final uri = Uri.parse(endpoint);
    
    return await http
        .patch(uri, headers: headers, body: json.encode(body))
        .timeout(timeout ?? AppConfig.apiTimeout);
  }

  /// Parse JSON response
  static Map<String, dynamic> parseJsonResponse(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }
    return json.decode(response.body);
  }

  /// Check if response is successful
  static bool isSuccessful(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Extract error message from response
  static String getErrorMessage(http.Response response) {
    try {
      final data = parseJsonResponse(response);
      return data['message'] ?? data['error'] ?? 'เกิดข้อผิดพลาด';
    } catch (e) {
      return 'เกิดข้อผิดพลาดในการประมวลผล';
    }
  }
}
