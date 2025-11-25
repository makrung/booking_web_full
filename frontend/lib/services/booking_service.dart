import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Original BookingService
/// Maintains backward compatibility with existing code
class BookingService {
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

  // ดึงข้อมูลสนามทั้งหมด
  static Future<Map<String, dynamic>> getCourts() async {
    try {
      print('🏟️ Fetching courts from: $baseUrl/courts');
      
      // ไม่ต้องใช้ auth headers เพราะ API /courts ไม่ต้องการ auth
      final response = await http.get(
        Uri.parse('$baseUrl/courts'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('getCourts response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('getCourts data keys: ${data.keys}');
        print('getCourts courts count: ${data['courts']?.length ?? 0}');
        return data;
      } else {
        print('getCourts error: ${response.body}');
        throw Exception('Failed to load courts: ${response.statusCode}');
      }
    } catch (e) {
      print('getCourts exception: $e');
      throw Exception('Error: $e');
    }
  }

  // ดึงการจองทั้งหมด (สำหรับ Schedule)
  static Future<Map<String, dynamic>> getAllBookings() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/all-bookings'),
        headers: headers,
      );

      print('getAllBookings response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load bookings');
      }
    } catch (e) {
      print('getAllBookings exception: $e');
      throw Exception('Error: $e');
    }
  }

  // ดึงการจองของผู้ใช้
  static Future<Map<String, dynamic>> getUserBookings() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/user-bookings'),
        headers: headers,
      );

      print('getUserBookings response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('getUserBookings data: $data');
        return data;
      } else {
        print('getUserBookings error: ${response.body}');
        throw Exception('Failed to load user bookings: ${response.statusCode}');
      }
    } catch (e) {
      print('getUserBookings exception: $e');
      throw Exception('Error: $e');
    }
  }

  // ดึงการจองของสนามในวันที่เฉพาะ
  static Future<Map<String, dynamic>> getBookingsByDate({
    required String courtId,
    required String date,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/court-schedule/$courtId/$date'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load bookings');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // สร้างการจอง
  static Future<Map<String, dynamic>> createBooking({
    required String courtId,
    required String courtName,
    required String date,
    required List<String> timeSlots,
    String bookingType = 'regular',
    List<String> participantCodes = const [],
  }) async {
    try {
      final headers = await _getAuthHeaders();
      print('Creating booking: courtId=$courtId, date=$date, timeSlots=$timeSlots');
      final response = await http.post(
        Uri.parse('$baseUrl/bookings'),
        headers: headers,
        body: json.encode({
          'courtId': courtId,
          'courtName': courtName,
          'date': date,
          'timeSlots': timeSlots,
          'bookingType': bookingType,
          'participantCodes': participantCodes,
        }),
      );

      print('createBooking response: ${response.statusCode}');
      final body = json.decode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return body;
      }
      // Allow 409 to bubble as a handled result for UI to process existing pending bookings
      if (response.statusCode == 409 && body is Map<String, dynamic>) {
        print('createBooking conflict (handled): $body');
        return body;
      }
      print('createBooking error: $body');
      throw Exception(body['error'] ?? 'Failed to create booking');
    } catch (e) {
      print('createBooking exception: $e');
      throw Exception('Error: $e');
    }
  }

  // ยกเลิกการจอง
  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      print('Cancelling booking: $bookingId');
      final response = await http.delete(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: headers,
      );

      print('cancelBooking response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        print('cancelBooking error: $error');
        throw Exception(error['error'] ?? 'Failed to cancel booking');
      }
    } catch (e) {
      print('cancelBooking exception: $e');
      throw Exception('Error: $e');
    }
  }

  // เช็คอิน/ยืนยันด้วย QR (รองรับทั้ง JSON และข้อความชื่อสนาม)
  static Future<Map<String, dynamic>> confirmBookingWithQR({
    required String bookingId,
    required String qrData,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      print('Confirming booking with QR: bookingId=$bookingId');
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/confirm-qr'),
        headers: headers,
        body: json.encode({
          'bookingId': bookingId,
          'qrData': qrData,
          if (latitude != null && longitude != null)
            'location': {
              'latitude': latitude,
              'longitude': longitude,
            },
        }),
      );

      print('confirmBookingWithQR response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        print('confirmBookingWithQR error: $error');
        throw Exception(error['error'] ?? 'Failed to confirm booking');
      }
    } catch (e) {
      print('confirmBookingWithQR exception: $e');
      throw Exception('Error: $e');
    }
  }

  // อัพเดทสถานะการจอง
  static Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId/status'),
        headers: headers,
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to update status');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ส่งคำขอจองกิจกรรม
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

  // Alias for createActivityRequest (backward compatibility)
  static Future<Map<String, dynamic>> createActivityRequest({
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
    return submitActivityRequest(
      responsiblePersonName: responsiblePersonName,
      responsiblePersonId: responsiblePersonId,
      responsiblePersonPhone: responsiblePersonPhone,
      responsiblePersonEmail: responsiblePersonEmail,
      activityName: activityName,
      activityDescription: activityDescription,
      activityDate: activityDate,
      timeSlot: timeSlot,
      courtId: courtId,
      organizationDocument: organizationDocument,
    );
  }

  // ดึงตารางการจองสนาม
  static Future<Map<String, dynamic>> getCourtSchedule(String courtId, String date) async {
    return getBookingsByDate(courtId: courtId, date: date);
  }

  // สร้างช่วงเวลาตามเวลาเปิดปิดของสนาม
  static List<String> buildTimeSlotsFromCourt(Map<String, dynamic> court) {
    String start = (court['playStartTime'] ?? '08:00') as String;
    String end = (court['playEndTime'] ?? '22:00') as String;
    int startH = int.parse(start.split(':')[0]);
    int endH = int.parse(end.split(':')[0]);
    final List<String> slots = [];
    for (int h = startH; h < endH; h++) {
      final a = h.toString().padLeft(2, '0');
      final b = (h + 1).toString().padLeft(2, '0');
      slots.add('$a:00-$b:00');
    }
    return slots;
  }

  // สถานะการใช้โค้ดของผู้ใช้วันนี้
  static Future<Map<String, dynamic>> getCodeStatus() async {
    try {
      final headers = await _getAuthHeaders();
      final resp = await http.get(Uri.parse('$baseUrl/bookings/code-status'), headers: headers);
      if (resp.statusCode == 200) {
        return json.decode(resp.body);
      } else {
        final err = json.decode(resp.body);
        throw Exception(err['error'] ?? 'Failed to get code status');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ดึงประเภทกิจกรรม
  static List<String> getActivityTypes() {
    return [
      'กีฬา',
      'กิจกรรมองค์กร',
      'การแสดง',
      'การประชุม',
      'อื่นๆ',
    ];
  }

  // ยืนยันแทนที่การจอง
  static Future<Map<String, dynamic>> confirmReplaceBooking({
    required String courtId,
    required String date,
    required List<String> timeSlots,
    String courtName = '',
    List<String> participantCodes = const [],
  }) async {
    return createBooking(
      courtId: courtId,
      courtName: courtName,
      date: date,
      timeSlots: timeSlots,
      bookingType: 'regular',
      participantCodes: participantCodes,
    );
  }
}
