/// Application-wide constants
/// Centralized location for all status codes, types, and enums
class AppConstants {
  AppConstants._();
}

/// Booking status constants
class BookingStatus {
  BookingStatus._();
  
  // Main statuses
  static const String pending = 'pending';              // รอการยืนยัน QR Code
  static const String confirmed = 'confirmed';          // ยืนยัน QR Code แล้ว
  static const String checkedIn = 'checked-in';         // เช็คอินสำเร็จ (ยืนยันตำแหน่งแล้ว)
  static const String completed = 'completed';          // ใช้งานเสร็จสิ้น
  static const String cancelled = 'cancelled';          // ยกเลิกโดยผู้ใช้
  static const String expired = 'expired';              // หมดอายุ (ไม่มายืนยัน QR)
  static const String noShow = 'no-show';              // ไม่มาใช้งาน (ยืนยัน QR แล้วแต่ไม่เช็คอิน)
  static const String penalized = 'penalized';         // โดนหักคะแนนแล้ว
  
  /// Get all valid statuses
  static List<String> get allStatuses => [
        pending,
        confirmed,
        checkedIn,
        completed,
        cancelled,
        expired,
        noShow,
        penalized,
      ];
  
  /// Check if status is valid
  static bool isValid(String status) => allStatuses.contains(status);
  
  /// Get Thai text for status
  static String getStatusText(String status) {
    switch (status) {
      case pending:
        return 'รอการยืนยัน QR';
      case confirmed:
        return 'ยืนยัน QR แล้ว';
      case checkedIn:
        return 'เช็คอินแล้ว';
      case completed:
        return 'เสร็จสิ้น';
      case cancelled:
        return 'ยกเลิกแล้ว';
      case expired:
        return 'หมดอายุ';
      case noShow:
        return 'ไม่มาใช้งาน';
      case penalized:
        return 'โดนหักคะแนน';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }
  
  /// Get color for status (Flutter Color name as string)
  static String getStatusColor(String status) {
    switch (status) {
      case pending:
        return 'orange';
      case confirmed:
        return 'blue';
      case checkedIn:
        return 'purple';
      case completed:
        return 'green';
      case cancelled:
        return 'grey';
      case expired:
        return 'red';
      case noShow:
        return 'red';
      case penalized:
        return 'darkred';
      default:
        return 'grey';
    }
  }
  
  /// Status colors map (hex colors)
  static const Map<String, String> statusColors = {
    pending: '#FF9800',      // Orange
    confirmed: '#2196F3',    // Blue
    checkedIn: '#9C27B0',    // Purple
    completed: '#4CAF50',    // Green
    cancelled: '#9E9E9E',    // Grey
    expired: '#F44336',      // Red
    noShow: '#D32F2F',       // Dark Red
    penalized: '#B71C1C',    // Darker Red
  };
  
  /// Status icons map
  static const Map<String, String> statusIcons = {
    pending: '⏳',
    confirmed: '✅',
    checkedIn: '📍',
    completed: '🎉',
    cancelled: '❌',
    expired: '⏰',
    noShow: '🚫',
    penalized: '⚠️',
  };
  
  /// Status messages map
  static const Map<String, String> statusMessages = {
    pending: 'รอการยืนยัน QR Code',
    confirmed: 'ยืนยัน QR Code แล้ว',
    checkedIn: 'เช็คอินสำเร็จ',
    completed: 'ใช้งานเสร็จสิ้น',
    cancelled: 'ยกเลิกการจอง',
    expired: 'หมดเวลา (ไม่ได้เข้าใช้)',
    noShow: 'ไม่มาตามเวลาที่จอง',
    penalized: 'โดนหักคะแนน',
  };
  
  /// Status descriptions map
  static const Map<String, String> statusDescriptions = {
    pending: 'กรุณายืนยัน QR Code ภายในเวลาที่กำหนด',
    confirmed: 'รอเช็คอินที่สนามในวันและเวลาที่จอง',
    checkedIn: 'กำลังใช้งานสนาม',
    completed: 'ใช้งานสนามเสร็จสิ้นแล้ว',
    cancelled: 'การจองถูกยกเลิกแล้ว',
    expired: 'หมดเวลายืนยัน QR Code',
    noShow: 'ไม่ได้เข้าใช้งานสนามตามเวลาที่จอง',
    penalized: 'ถูกหักคะแนนเนื่องจากไม่มาใช้งาน',
  };
  
  /// Check if booking can be cancelled
  static bool canBeCancelled(String status) {
    return status == pending || status == confirmed;
  }
  
  /// Check if booking can be cancelled (alias)
  static bool canCancel(String status) => canBeCancelled(status);
  
  /// Check if booking can be checked in
  static bool canBeCheckedIn(String status) {
    return status == confirmed;
  }
  
  /// Check if booking is active
  static bool isActive(String status) {
    return status == pending || status == confirmed || status == checkedIn;
  }
  
  /// Check if status affects points
  static bool affectsPoints(String status) {
    return status == noShow || status == expired || status == penalized;
  }
}

/// Activity request status constants
class ActivityRequestStatus {
  ActivityRequestStatus._();
  
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  
  /// Get all valid statuses
  static List<String> get allStatuses => [pending, approved, rejected];
  
  /// Check if status is valid
  static bool isValid(String status) => allStatuses.contains(status);
  
  /// Get Thai text for status
  static String getStatusText(String status) {
    switch (status) {
      case pending:
        return 'รอการอนุมัติ';
      case approved:
        return 'อนุมัติแล้ว';
      case rejected:
        return 'ปฏิเสธ';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }
  
  /// Get color for status
  static String getStatusColor(String status) {
    switch (status) {
      case pending:
        return 'orange';
      case approved:
        return 'green';
      case rejected:
        return 'red';
      default:
        return 'grey';
    }
  }
}

/// Booking type constants
class BookingType {
  BookingType._();
  
  static const String regular = 'regular';      // จองใช้งานทั่วไป
  static const String activity = 'activity';    // จองเพื่อกิจกรรม
  
  /// Get all valid types
  static List<String> get allTypes => [regular, activity];
  
  /// Check if type is valid
  static bool isValid(String type) => allTypes.contains(type);
  
  /// Get Thai text for type
  static String getTypeText(String type) {
    switch (type) {
      case regular:
        return 'จองทั่วไป';
      case activity:
        return 'จองกิจกรรม';
      default:
        return 'ไม่ทราบประเภท';
    }
  }
}

/// Court type constants
class CourtType {
  CourtType._();
  
  static const String outdoor = 'outdoor';      // สนามกลางแจ้ง
  static const String indoor = 'indoor';        // สนามในร่ม
  
  /// Get all valid types
  static List<String> get allTypes => [outdoor, indoor];
  
  /// Check if type is valid
  static bool isValid(String type) => allTypes.contains(type);
  
  /// Get Thai text for type
  static String getTypeText(String type) {
    switch (type) {
      case outdoor:
        return 'สนามกลางแจ้ง';
      case indoor:
        return 'สนามในร่ม';
      default:
        return 'ไม่ทราบประเภท';
    }
  }
}

/// Sport category constants
class SportCategory {
  SportCategory._();
  
  static const String football = 'football';
  static const String futsal = 'futsal';
  static const String basketball = 'basketball';
  static const String volleyball = 'volleyball';
  static const String badminton = 'badminton';
  static const String tennis = 'tennis';
  static const String takraw = 'takraw';
  static const String multipurpose = 'multipurpose';
  
  /// Get all valid categories
  static List<String> get allCategories => [
        football,
        futsal,
        basketball,
        volleyball,
        badminton,
        tennis,
        takraw,
        multipurpose,
      ];
  
  /// Check if category is valid
  static bool isValid(String category) => allCategories.contains(category);
  
  /// Get Thai text for category
  static String getCategoryText(String category) {
    switch (category) {
      case football:
        return 'ฟุตบอล';
      case futsal:
        return 'ฟุตซอล';
      case basketball:
        return 'บาสเกตบอล';
      case volleyball:
        return 'วอลเลย์บอล';
      case badminton:
        return 'แบดมินตัน';
      case tennis:
        return 'เทนนิส';
      case takraw:
        return 'ตะกร้อ';
      case multipurpose:
        return 'อเนกประสงค์';
      default:
        return 'ไม่ทราบประเภท';
    }
  }
}

/// Penalty type constants
class PenaltyType {
  PenaltyType._();
  
  static const String noShow = 'no-show';
  static const String lateCancel = 'late-cancel';
  static const String noQrConfirmation = 'no-qr-confirmation';
  static const String other = 'other';
  
  /// Get all valid types
  static List<String> get allTypes => [noShow, lateCancel, noQrConfirmation, other];
  
  /// Check if type is valid
  static bool isValid(String type) => allTypes.contains(type);
  
  /// Get Thai text for type
  static String getTypeText(String type) {
    switch (type) {
      case noShow:
        return 'ไม่มาใช้งาน';
      case lateCancel:
        return 'ยกเลิกช้า';
      case noQrConfirmation:
        return 'ไม่ยืนยัน QR';
      case other:
        return 'อื่นๆ';
      default:
        return 'ไม่ทราบประเภท';
    }
  }
}

/// User role constants
class UserRole {
  UserRole._();
  
  static const String admin = 'admin';
  static const String user = 'user';
  
  /// Get all valid roles
  static List<String> get allRoles => [admin, user];
  
  /// Check if role is valid
  static bool isValid(String role) => allRoles.contains(role);
  
  /// Check if role is admin
  static bool isAdmin(String role) => role == admin;
}

/// Time slot constants
class TimeSlot {
  TimeSlot._();
  
  // Common time slots
  static const String slot0800_1000 = '08:00-10:00';
  static const String slot1000_1200 = '10:00-12:00';
  static const String slot1200_1400 = '12:00-14:00';
  static const String slot1400_1600 = '14:00-16:00';
  static const String slot1600_1800 = '16:00-18:00';
  static const String slot1800_2000 = '18:00-20:00';
  static const String slot2000_2200 = '20:00-22:00';
  
  /// Get all standard time slots
  static List<String> get standardSlots => [
        slot0800_1000,
        slot1000_1200,
        slot1200_1400,
        slot1400_1600,
        slot1600_1800,
        slot1800_2000,
        slot2000_2200,
      ];
}
