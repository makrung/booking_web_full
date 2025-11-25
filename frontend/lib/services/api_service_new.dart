import '../core/base_service.dart';
import '../config/app_config.dart';

/// Refactored API Service using BaseService
/// This eliminates code duplication and provides cleaner API
class ApiService extends BaseService {
  // Register user
  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String studentId,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await BaseService.post(
        AppConfig.authRegister,
        {
          'firstName': firstName,
          'lastName': lastName,
          'studentId': studentId,
          'email': email,
          'phone': phone,
          'password': password,
        },
        includeAuth: false,
      );

      final data = BaseService.parseJsonResponse(response);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'userId': data['userId'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'เกิดข้อผิดพลาด',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e',
      };
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await BaseService.post(
        AppConfig.authLogin,
        {
          'email': email,
          'password': password,
        },
        includeAuth: false,
      );

      final data = BaseService.parseJsonResponse(response);

      if (response.statusCode == 200) {
        // Save token if login successful
        if (data['token'] != null) {
          await BaseService.saveToken(data['token']);
        }

        return {
          'success': true,
          'message': data['message'],
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'เกิดข้อผิดพลาด',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e',
      };
    }
  }

  // Get current user info
  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await BaseService.get('${AppConfig.apiBaseUrl}/auth/me');
      final data = BaseService.parseJsonResponse(response);

      if (BaseService.isSuccessful(response)) {
        return {
          'success': true,
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': BaseService.getErrorMessage(response),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e',
      };
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (firstName != null) body['firstName'] = firstName;
      if (lastName != null) body['lastName'] = lastName;
      if (phone != null) body['phone'] = phone;

      final response = await BaseService.put(
        '${AppConfig.apiBaseUrl}/users/$userId',
        body,
      );

      final data = BaseService.parseJsonResponse(response);

      if (BaseService.isSuccessful(response)) {
        return {
          'success': true,
          'message': data['message'] ?? 'อัปเดตข้อมูลสำเร็จ',
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': BaseService.getErrorMessage(response),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e',
      };
    }
  }

  // Send verification email
  static Future<Map<String, dynamic>> sendVerificationEmail(String email) async {
    try {
      final response = await BaseService.post(
        '${AppConfig.apiBaseUrl}/auth/send-verification',
        {'email': email},
        includeAuth: false,
      );

      final data = BaseService.parseJsonResponse(response);

      if (BaseService.isSuccessful(response)) {
        return {
          'success': true,
          'message': data['message'] ?? 'ส่งอีเมลยืนยันสำเร็จ',
        };
      } else {
        return {
          'success': false,
          'message': BaseService.getErrorMessage(response),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e',
      };
    }
  }

  // Verify email with token
  static Future<Map<String, dynamic>> verifyEmail(String token) async {
    try {
      final response = await BaseService.get(
        '${AppConfig.authVerifyEmail}/$token',
        includeAuth: false,
      );

      final data = BaseService.parseJsonResponse(response);

      if (BaseService.isSuccessful(response)) {
        return {
          'success': true,
          'message': data['message'] ?? 'ยืนยันอีเมลสำเร็จ',
        };
      } else {
        return {
          'success': false,
          'message': BaseService.getErrorMessage(response),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e',
      };
    }
  }

  // Change password
  static Future<Map<String, dynamic>> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await BaseService.put(
        '${AppConfig.apiBaseUrl}/users/$userId/password',
        {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );

      final data = BaseService.parseJsonResponse(response);

      if (BaseService.isSuccessful(response)) {
        return {
          'success': true,
          'message': data['message'] ?? 'เปลี่ยนรหัสผ่านสำเร็จ',
        };
      } else {
        return {
          'success': false,
          'message': BaseService.getErrorMessage(response),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e',
      };
    }
  }

  // Get user points
  static Future<Map<String, dynamic>> getUserPoints(String userId) async {
    try {
      final response = await BaseService.get(
        '${AppConfig.apiBaseUrl}/users/$userId/points',
      );

      final data = BaseService.parseJsonResponse(response);

      if (BaseService.isSuccessful(response)) {
        return {
          'success': true,
          'points': data['points'],
          'history': data['history'],
        };
      } else {
        return {
          'success': false,
          'message': BaseService.getErrorMessage(response),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e',
      };
    }
  }

  // Logout (clear token)
  static Future<void> logout() async {
    await BaseService.removeToken();
  }
}
