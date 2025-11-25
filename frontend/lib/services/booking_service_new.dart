import '../core/base_service.dart';
import '../core/exceptions.dart';
import '../config/app_config.dart';
// Use the stable new court model implementation
import '../models/court_model_new.dart';
import '../models/api_response.dart';

/// Refactored BookingService using BaseService
/// Eliminates code duplication and provides cleaner API
class BookingServiceRefactored extends BaseService {
  
  // ดึงข้อมูลสนามทั้งหมด (ใช้ข้อมูลจาก local model)
  static Future<ApiResponse<Map<String, dynamic>>> getCourts() async {
    try {
      // ใช้ข้อมูลจาก CourtData model แทนการเรียก API
      final allCourts = CourtData.getAllCourts();
      final courtsMap = <String, dynamic>{};
      
      for (var court in allCourts) {
        courtsMap[court.id] = court.toJson();
      }

      return ApiResponse.success(data: courtsMap);
    } catch (e) {
      return ApiResponse.error(
        message: 'ไม่สามารถโหลดข้อมูลสนามได้',
        error: e,
      );
    }
  }

  // ดึงสนามตามประเภท
  static Future<ApiResponse<Map<String, dynamic>>> getCourtsByType(String type) async {
    try {
      final courts = CourtData.getCourtsByType(type);
      final courtsMap = <String, dynamic>{};
      
      for (var court in courts) {
        courtsMap[court.id] = court.toJson();
      }

      return ApiResponse.success(data: courtsMap);
    } catch (e) {
      return ApiResponse.error(
        message: 'ไม่สามารถโหลดข้อมูลสนามได้',
        error: e,
      );
    }
  }

  // ดึงหมวดหมู่สนาม
  static List<Map<String, dynamic>> getCourtCategories() {
    return CourtData.getCourtCategories();
  }

  // ดึงตารางการจองของสนามในวันนั้น
  static Future<ApiResponse<List<String>>> getCourtSchedule(
    String courtId,
    String date,
  ) async {
    try {
      final response = await BaseService.get(
        '${AppConfig.apiBaseUrl}/court-schedule/$courtId/$date',
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        final bookedSlots = List<String>.from(data['bookedSlots'] ?? []);
        return ApiResponse.success(data: bookedSlots);
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการโหลดตาราง',
        error: e,
      );
    }
  }

  // จองสนาม
  static Future<ApiResponse<Map<String, dynamic>>> bookCourt({
    required String courtId,
    required String date,
    required String timeSlot,
    String? activityRequestId,
  }) async {
    try {
      final response = await BaseService.post(
        AppConfig.bookings,
        {
          'courtId': courtId,
          'date': date,
          'timeSlot': timeSlot,
          if (activityRequestId != null) 'activityRequestId': activityRequestId,
        },
      );

      final data = BaseService.parseJsonResponse(response);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse.success(
          message: data['message'] ?? 'จองสนามสำเร็จ',
          data: data,
        );
      } else {
        return ApiResponse.error(
          message: data['error'] ?? 'ไม่สามารถจองสนามได้',
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } on UnauthorizedException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการจองสนาม',
        error: e,
      );
    }
  }

  // ดึงประวัติการจอง
  static Future<ApiResponse<List<Map<String, dynamic>>>> getBookingHistory() async {
    try {
      final response = await BaseService.get(AppConfig.bookings);

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        final bookings = List<Map<String, dynamic>>.from(data['bookings'] ?? []);
        return ApiResponse.success(data: bookings);
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการโหลดประวัติ',
        error: e,
      );
    }
  }

  // ยกเลิกการจอง
  static Future<ApiResponse<void>> cancelBooking(String bookingId) async {
    try {
      final response = await BaseService.delete(
        '${AppConfig.bookings}/$bookingId',
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        return ApiResponse.success(
          message: data['message'] ?? 'ยกเลิกการจองสำเร็จ',
        );
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการยกเลิกการจอง',
        error: e,
      );
    }
  }

  // ยืนยัน QR Code
  static Future<ApiResponse<Map<String, dynamic>>> confirmQRCode({
    required String bookingId,
    required String qrCode,
  }) async {
    try {
      final response = await BaseService.post(
        '${AppConfig.bookings}/$bookingId/confirm',
        {'qrCode': qrCode},
      );

      final data = BaseService.parseJsonResponse(response);

      if (BaseService.isSuccessful(response)) {
        return ApiResponse.success(
          message: data['message'] ?? 'ยืนยัน QR Code สำเร็จ',
          data: data,
        );
      } else {
        return ApiResponse.error(
          message: data['error'] ?? 'ไม่สามารถยืนยัน QR Code ได้',
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการยืนยัน QR Code',
        error: e,
      );
    }
  }

  // เช็คอิน (ยืนยันตำแหน่ง)
  static Future<ApiResponse<Map<String, dynamic>>> checkIn({
    required String bookingId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await BaseService.post(
        '${AppConfig.bookings}/$bookingId/checkin',
        {
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      final data = BaseService.parseJsonResponse(response);

      if (BaseService.isSuccessful(response)) {
        return ApiResponse.success(
          message: data['message'] ?? 'เช็คอินสำเร็จ',
          data: data,
        );
      } else {
        return ApiResponse.error(
          message: data['error'] ?? 'ไม่สามารถเช็คอินได้',
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการเช็คอิน',
        error: e,
      );
    }
  }

  // เช็คว่าสามารถจองได้หรือไม่
  static Future<ApiResponse<bool>> canBook({
    required String courtId,
    required String date,
    required String timeSlot,
  }) async {
    try {
      // เช็คจาก booking rules
      final courtData = CourtData.getCourtById(courtId);
      if (courtData == null) {
        return ApiResponse.error(message: 'ไม่พบข้อมูลสนาม');
      }

      // เช็คกับเซิร์ฟเวอร์
      final response = await BaseService.post(
        '${AppConfig.bookings}/check-availability',
        {
          'courtId': courtId,
          'date': date,
          'timeSlot': timeSlot,
        },
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        return ApiResponse.success(data: data['available'] ?? false);
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการตรวจสอบ',
        error: e,
      );
    }
  }

  // ดึงการจองในอนาคต
  static Future<ApiResponse<List<Map<String, dynamic>>>> getUpcomingBookings() async {
    try {
      final response = await BaseService.get(
        '${AppConfig.bookings}?status=upcoming',
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        final bookings = List<Map<String, dynamic>>.from(data['bookings'] ?? []);
        return ApiResponse.success(data: bookings);
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการโหลดข้อมูล',
        error: e,
      );
    }
  }

  // อัปเดตสถานะการจอง
  static Future<ApiResponse<void>> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      final response = await BaseService.patch(
        '${AppConfig.bookings}/$bookingId/status',
        {'status': status},
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        return ApiResponse.success(
          message: data['message'] ?? 'อัปเดตสถานะสำเร็จ',
        );
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการอัปเดตสถานะ',
        error: e,
      );
    }
  }
}
