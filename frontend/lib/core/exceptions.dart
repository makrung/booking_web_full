/// Custom exceptions for better error handling
class AppException implements Exception {
  final String message;
  final dynamic originalError;

  AppException(this.message, [this.originalError]);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([String message = 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์'])
      : super(message);
}

class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'กรุณาเข้าสู่ระบบใหม่'])
      : super(message);
}

class ValidationException extends AppException {
  final Map<String, List<String>>? errors;

  ValidationException(String message, [this.errors]) : super(message);
}

class NotFoundException extends AppException {
  NotFoundException([String message = 'ไม่พบข้อมูลที่ต้องการ'])
      : super(message);
}

class ServerException extends AppException {
  ServerException([String message = 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์'])
      : super(message);
}

class PermissionDeniedException extends AppException {
  PermissionDeniedException([String message = 'คุณไม่มีสิทธิ์ดำเนินการนี้'])
      : super(message);
}
