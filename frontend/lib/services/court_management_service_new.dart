import 'dart:convert';
import '../core/base_service.dart';

class CourtManagementService extends BaseService {
  // ดึงข้อมูลสนามทั้งหมด
  static Future<Map<String, dynamic>> getAllCourts() async {
    try {
      // ใช้ BaseService method สำหรับ GET request
      final response = await BaseService.get(
        'http://localhost:3000/api/courts',
        includeAuth: false,
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('API Response Courts Count: ${result['courts']?.length ?? 0}'); // Debug log
        return result;
      } else {
        print('API Error: ${response.statusCode} - ${response.body}'); // Debug log
        throw Exception('ไม่สามารถโหลดข้อมูลสนามได้: ${response.statusCode}');
      }
    } catch (e) {
      print('Service Error: $e'); // Debug log
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // ดึงข้อมูลสนามตามประเภท
  static Future<Map<String, dynamic>> getCourtsByType(String type) async {
    try {
      final response = await BaseService.get(
        'http://localhost:3000/api/courts/type/$type',
        includeAuth: false,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('ไม่สามารถโหลดข้อมูลสนามได้');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // ดึงข้อมูลสนามตามหมวดหมู่
  static Future<Map<String, dynamic>> getCourtsByCategory(String category) async {
    try {
      final response = await BaseService.get(
        'http://localhost:3000/api/courts/category/$category',
        includeAuth: false,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('ไม่สามารถโหลดข้อมูลสนามได้');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // ดึงข้อมูลสนามเฉพาะ
  static Future<Map<String, dynamic>> getCourt(String courtId) async {
    try {
      final response = await BaseService.get(
        'http://localhost:3000/api/courts/$courtId',
        includeAuth: false,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('ไม่พบข้อมูลสนาม');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // เพิ่มสนามใหม่
  static Future<Map<String, dynamic>> addCourt(Map<String, dynamic> courtData) async {
    try {
      print('🔵 Adding court - Data: $courtData');
      
      // ตรวจสอบ token ก่อนส่ง
      final token = await BaseService.getToken();
      print('🔵 Current token: ${token?.substring(0, 20)}...');
      
      final response = await BaseService.post(
        'http://localhost:3000/api/admin/courts',
        courtData,
        includeAuth: true,
      );

      print('🔵 Add court response: ${response.statusCode}');
      print('🔵 Add court body: ${response.body}');

      final responseData = json.decode(response.body);
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'],
          'court': responseData['court']
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'เกิดข้อผิดพลาดในการเพิ่มสนาม'
        };
      }
    } catch (e) {
      print('🔴 Add court error: $e');
      return {
        'success': false,
        'error': 'เกิดข้อผิดพลาด: $e'
      };
    }
  }

  // แก้ไขข้อมูลสนาม
  static Future<Map<String, dynamic>> updateCourt(String courtId, Map<String, dynamic> courtData) async {
    try {
      print('🔵 Updating court $courtId - Data: $courtData');
      
      // ตรวจสอบ token ก่อนส่ง
      final token = await BaseService.getToken();
      print('🔵 Current token: ${token?.substring(0, 20)}...');
      
      final response = await BaseService.put(
        'http://localhost:3000/api/admin/courts/$courtId',
        courtData,
        includeAuth: true,
      );

      print('🔵 Update court response: ${response.statusCode}');
      print('🔵 Update court body: ${response.body}');

      final responseData = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
          'court': responseData['court']
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'เกิดข้อผิดพลาดในการแก้ไขสนาม'
        };
      }
    } catch (e) {
      print('🔴 Update court error: $e');
      return {
        'success': false,
        'error': 'เกิดข้อผิดพลาด: $e'
      };
    }
  }

  // ลบสนาม
  static Future<Map<String, dynamic>> deleteCourt(String courtId) async {
    try {
      final response = await BaseService.delete(
        'http://localhost:3000/api/admin/courts/$courtId',
        includeAuth: true,
      );

      final responseData = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
          'deletedCourt': responseData['deletedCourt']
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'เกิดข้อผิดพลาดในการลบสนาม'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'เกิดข้อผิดพลาด: $e'
      };
    }
  }

  // เปิด/ปิดการใช้งานสนาม
  static Future<Map<String, dynamic>> toggleCourtAvailability(String courtId) async {
    try {
      final response = await BaseService.patch(
        'http://localhost:3000/api/admin/courts/$courtId/toggle-availability',
        {},
        includeAuth: true,
      );

      final responseData = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
          'court': responseData['court']
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'เกิดข้อผิดพลาดในการเปลี่ยนสถานะสนาม'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'เกิดข้อผิดพลาด: $e'
      };
    }
  }

  // ดึงสถิติการใช้งานสนาม
  static Future<Map<String, dynamic>> getCourtStatistics(String courtId, {String? startDate, String? endDate}) async {
    try {
      String url = 'http://localhost:3000/api/admin/courts/$courtId/statistics';
      
      // เพิ่ม query parameters ถ้ามี
      final queryParams = <String>[];
      if (startDate != null) queryParams.add('startDate=$startDate');
      if (endDate != null) queryParams.add('endDate=$endDate');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await BaseService.get(
        url,
        includeAuth: true,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('ไม่สามารถโหลดสถิติการใช้งานสนามได้');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // Utility methods
  static List<Map<String, String>> getCourtTypes() {
    return [
      {'value': 'outdoor', 'label': 'กลางแจ้ง'},
      {'value': 'indoor', 'label': 'ในร่ม'},
    ];
  }

  static List<Map<String, String>> getCourtCategories() {
    return [
      {'value': 'tennis', 'label': 'เทนนิส'},
      {'value': 'basketball', 'label': 'บาสเกตบอล'},
      {'value': 'badminton', 'label': 'แบดมินตัน'},
      {'value': 'futsal', 'label': 'ฟุตซอล'},
      {'value': 'football', 'label': 'ฟุตบอล'},
      {'value': 'volleyball', 'label': 'วอลเลย์บอล'},
      {'value': 'takraw', 'label': 'ตะกร้อ'},
      {'value': 'multipurpose', 'label': 'อเนกประสงค์'},
    ];
  }

  static String getTypeLabel(String type) {
    switch (type) {
      case 'outdoor': return 'กลางแจ้ง';
      case 'indoor': return 'ในร่ม';
      default: return type;
    }
  }

  static String getCategoryLabel(String category) {
    switch (category) {
      case 'tennis': return 'เทนนิส';
      case 'basketball': return 'บาสเกตบอล';
      case 'badminton': return 'แบดมินตัน';
      case 'futsal': return 'ฟุตซอล';
      case 'football': return 'ฟุตบอล';
      case 'volleyball': return 'วอลเลย์บอล';
      case 'takraw': return 'ตะกร้อ';
      case 'multipurpose': return 'อเนกประสงค์';
      default: return category;
    }
  }

  // ตรวจสอบความถูกต้องของข้อมูลสนาม
  static Map<String, String?> validateCourtData(Map<String, dynamic> data) {
    final errors = <String, String?>{};

    if (data['name'] == null || data['name'].toString().trim().isEmpty) {
      errors['name'] = 'กรุณาระบุชื่อสนาม';
    }

    if (data['type'] == null || data['type'].toString().trim().isEmpty) {
      errors['type'] = 'กรุณาเลือกประเภทสนาม';
    }

    if (data['category'] == null || data['category'].toString().trim().isEmpty) {
      errors['category'] = 'กรุณาเลือกหมวดหมู่สนาม';
    }

    if (data['number'] == null) {
      errors['number'] = 'กรุณาระบุหมายเลขสนาม';
    } else {
      try {
        int.parse(data['number'].toString());
      } catch (e) {
        errors['number'] = 'หมายเลขสนามต้องเป็นตัวเลข';
      }
    }

    // ตรวจสอบรูปแบบเวลา
    final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    
    if (data['openBookingTime'] == null || !timeRegex.hasMatch(data['openBookingTime'].toString())) {
      errors['openBookingTime'] = 'รูปแบบเวลาเปิดจองไม่ถูกต้อง (ใช้รูปแบบ HH:MM)';
    }

    if (data['playStartTime'] == null || !timeRegex.hasMatch(data['playStartTime'].toString())) {
      errors['playStartTime'] = 'รูปแบบเวลาเริ่มเล่นไม่ถูกต้อง (ใช้รูปแบบ HH:MM)';
    }

    if (data['playEndTime'] == null || !timeRegex.hasMatch(data['playEndTime'].toString())) {
      errors['playEndTime'] = 'รูปแบบเวลาปิดสนามไม่ถูกต้อง (ใช้รูปแบบ HH:MM)';
    }

    // ตรวจสอบพิกัด (ถ้ามี)
    if (data['location'] != null) {
      final location = data['location'] as Map<String, dynamic>;
      
      if (location['latitude'] != null) {
        try {
          final lat = double.parse(location['latitude'].toString());
          if (lat < -90 || lat > 90) {
            errors['latitude'] = 'ละติจูดต้องอยู่ระหว่าง -90 ถึง 90';
          }
        } catch (e) {
          errors['latitude'] = 'ละติจูดต้องเป็นตัวเลข';
        }
      }

      if (location['longitude'] != null) {
        try {
          final lng = double.parse(location['longitude'].toString());
          if (lng < -180 || lng > 180) {
            errors['longitude'] = 'ลองจิจูดต้องอยู่ระหว่าง -180 ถึง 180';
          }
        } catch (e) {
          errors['longitude'] = 'ลองจิจูดต้องเป็นตัวเลข';
        }
      }
    }

    return errors;
  }
}