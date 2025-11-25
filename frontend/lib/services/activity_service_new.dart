import '../core/base_service.dart';
import '../core/exceptions.dart';
import '../config/app_config.dart';
import '../models/api_response.dart';
import '../models/activity_request.dart';

/// Refactored ActivityService using BaseService
class ActivityServiceRefactored extends BaseService {
  
  // ส่งคำขอจองสำหรับกิจกรรม
  static Future<ApiResponse<String>> submitActivityRequest({
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
      final response = await BaseService.post(
        AppConfig.activities,
        {
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
        },
      );

      final data = BaseService.parseJsonResponse(response);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse.success(
          message: data['message'] ?? 'ส่งคำขอสำเร็จ',
          data: data['requestId'],
        );
      } else {
        return ApiResponse.error(
          message: data['error'] ?? 'ไม่สามารถส่งคำขอได้',
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการส่งคำขอ',
        error: e,
      );
    }
  }

  // ดึงรายการคำขอทั้งหมด (สำหรับ admin)
  static Future<ApiResponse<List<ActivityRequest>>> getAllRequests({
    String? status,
  }) async {
    try {
      final queryParams = status != null ? '?status=$status' : '';
      final response = await BaseService.get(
        '${AppConfig.activities}$queryParams',
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        final requests = (data['requests'] as List)
            .map((json) => ActivityRequest.fromJson(json))
            .toList();
        return ApiResponse.success(data: requests);
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการโหลดข้อมูล',
        error: e,
      );
    }
  }

  // ดึงคำขอของผู้ใช้
  static Future<ApiResponse<List<ActivityRequest>>> getUserRequests() async {
    try {
      final response = await BaseService.get(
        '${AppConfig.activities}/my-requests',
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        final requests = (data['requests'] as List)
            .map((json) => ActivityRequest.fromJson(json))
            .toList();
        return ApiResponse.success(data: requests);
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการโหลดข้อมูล',
        error: e,
      );
    }
  }

  // ดึงข้อมูลคำขอเดียว
  static Future<ApiResponse<ActivityRequest>> getRequestById(String requestId) async {
    try {
      final response = await BaseService.get(
        '${AppConfig.activities}/$requestId',
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        final request = ActivityRequest.fromJson(data['request']);
        return ApiResponse.success(data: request);
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการโหลดข้อมูล',
        error: e,
      );
    }
  }

  // อนุมัติคำขอ (admin only)
  static Future<ApiResponse<void>> approveRequest({
    required String requestId,
    required String adminId,
  }) async {
    try {
      final response = await BaseService.post(
        '${AppConfig.activities}/$requestId/approve',
        {'adminId': adminId},
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        return ApiResponse.success(
          message: data['message'] ?? 'อนุมัติคำขอสำเร็จ',
        );
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } on PermissionDeniedException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการอนุมัติคำขอ',
        error: e,
      );
    }
  }

  // ปฏิเสธคำขอ (admin only)
  static Future<ApiResponse<void>> rejectRequest({
    required String requestId,
    required String adminId,
    required String reason,
  }) async {
    try {
      final response = await BaseService.post(
        '${AppConfig.activities}/$requestId/reject',
        {
          'adminId': adminId,
          'reason': reason,
        },
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        return ApiResponse.success(
          message: data['message'] ?? 'ปฏิเสธคำขอสำเร็จ',
        );
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } on PermissionDeniedException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการปฏิเสธคำขอ',
        error: e,
      );
    }
  }

  // ยกเลิกคำขอ (user)
  static Future<ApiResponse<void>> cancelRequest(String requestId) async {
    try {
      final response = await BaseService.delete(
        '${AppConfig.activities}/$requestId',
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        return ApiResponse.success(
          message: data['message'] ?? 'ยกเลิกคำขอสำเร็จ',
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
        message: 'เกิดข้อผิดพลาดในการยกเลิกคำขอ',
        error: e,
      );
    }
  }

  // นับจำนวนคำขอแบ่งตามสถานะ (admin)
  static Future<ApiResponse<Map<String, int>>> getRequestStats() async {
    try {
      final response = await BaseService.get(
        '${AppConfig.activities}/stats',
      );

      if (BaseService.isSuccessful(response)) {
        final data = BaseService.parseJsonResponse(response);
        final stats = Map<String, int>.from(data['stats']);
        return ApiResponse.success(data: stats);
      } else {
        return ApiResponse.error(
          message: BaseService.getErrorMessage(response),
        );
      }
    } on NetworkException catch (e) {
      return ApiResponse.error(message: e.message);
    } catch (e) {
      return ApiResponse.error(
        message: 'เกิดข้อผิดพลาดในการโหลดสถิติ',
        error: e,
      );
    }
  }
}
