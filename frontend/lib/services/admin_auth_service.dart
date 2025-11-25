import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/base_service.dart';

class AdminAuthService {
  static const String baseUrl = 'http://localhost:3000/api';
  
  // สร้าง admin token สำหรับการจัดการสนาม
  static Future<Map<String, dynamic>> createAdminToken() async {
    try {
      print('🔐 Creating admin token...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/admin-token'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'adminSecret': 'your-admin-secret-key', // ใช้ secret key ที่กำหนดไว้
        }),
      );

      print('🔐 Admin token response: ${response.statusCode}');
      print('🔐 Admin token body: ${response.body}');

      final responseData = json.decode(response.body);
      
      if (response.statusCode == 200) {
        final token = responseData['token'];
        
        // บันทึก token
        await BaseService.saveToken(token);
        print('✅ Admin token saved successfully');
        
        return {
          'success': true,
          'token': token,
          'message': 'Admin token created successfully'
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to create admin token'
        };
      }
    } catch (e) {
      print('❌ Admin token creation error: $e');
      return {
        'success': false,
        'error': 'Error creating admin token: $e'
      };
    }
  }
  
  // ตรวจสอบว่ามี admin token หรือไม่
  static Future<bool> hasValidAdminToken() async {
    try {
      final token = await BaseService.getToken();
      if (token == null) {
        print('❌ No token found');
        return false;
      }
      
      // ทดสอบการเรียก admin API
      final response = await BaseService.get(
        '$baseUrl/admin/courts',
        includeAuth: true,
      );
      
      print('🔐 Token validation response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Token validation error: $e');
      return false;
    }
  }
  
  // รีเฟรช admin token ถ้าจำเป็น
  static Future<Map<String, dynamic>> ensureAdminToken() async {
    final hasValid = await hasValidAdminToken();
    
    if (!hasValid) {
      print('🔄 Need to create new admin token...');
      return await createAdminToken();
    }
    
    return {
      'success': true,
      'message': 'Admin token is valid'
    };
  }
}