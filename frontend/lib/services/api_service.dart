import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Original ApiService
/// Maintains backward compatibility with existing code
class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Register
  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String studentId,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'firstName': firstName,
          'lastName': lastName,
          'studentId': studentId,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // ส่งข้อมูลที่สมัครสำเร็จกลับไป
        return {
          'success': true,
          'message': data['message'] ?? 'สมัครสมาชิกสำเร็จ กรุณายืนยันอีเมล',
          'userId': data['userId'],
          'userType': data['userType'],
          'emailSent': data['emailSent'],
          'note': data['note'],
          ...data
        };
      } else {
        // ส่งข้อมูล error กลับไป
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? 'เกิดข้อผิดพลาดในการสมัครสมาชิก',
          'error': data['error']
        };
      }
    } catch (e) {
      // ส่งข้อมูล error กลับไป
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์',
        'error': e.toString()
      };
    }
  }

  // Login
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          await _saveToken(data['token']);
        }
        return data;
      } else {
        throw Exception(data['error'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get current user
  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get user info');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Logout
  static Future<void> logout() async {
    await _removeToken();
  }

  // Optional: get boolean setting from content API
  static Future<bool> getBooleanSetting(String key, {bool defaultValue = true}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/content/$key'), headers: {'Content-Type': 'application/json'});
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        final v = data['value'];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final s = v.toLowerCase().trim();
          return s == '1' || s == 'true' || s == 'yes' || s == 'on';
        }
      }
    } catch (_) {}
    return defaultValue;
  }

  // Resend verification email
  static Future<Map<String, dynamic>> resendVerificationEmail({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to resend email');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Verify email
  static Future<Map<String, dynamic>> verifyEmail(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/verify-email/$token'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Verification failed');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: headers,
        body: json.encode({
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Update failed');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Change password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: headers,
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Password change failed');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Request password reset
  static Future<Map<String, dynamic>> requestPasswordReset({ required String email }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/request-password-reset'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) return data;
      throw Exception(data['error'] ?? 'Request reset failed');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Reset password by token
  static Future<Map<String, dynamic>> resetPassword({ required String token, required String newPassword }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token, 'newPassword': newPassword}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) return data;
      throw Exception(data['error'] ?? 'Reset failed');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get token (for backward compatibility)
  static Future<String?> getToken() async {
    return _getToken();
  }

  // Save token (for backward compatibility)
  static Future<void> saveToken(String token) async {
    await _saveToken(token);
  }

  // Verify token
  static Future<Map<String, dynamic>> verifyToken() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/verify'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
          'statusCode': 200,
        };
      } else if (response.statusCode == 401) {
        // Token หมดอายุหรือไม่ถูกต้อง
        return {
          'success': false,
          'message': 'Token expired or invalid',
          'statusCode': 401,
        };
      } else {
        return {
          'success': false,
          'message': 'Token verification failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('ApiService: Error verifying token: $e');
      return {
        'success': false,
        'message': 'Connection error',
        'statusCode': 0,
      };
    }
  }
}
