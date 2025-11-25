import 'package:flutter_test/flutter_test.dart';
import 'package:booking_web_full/models/app_constants.dart';

void main() {
  group('BookingStatus Tests', () {
    test('All status constants are defined', () {
      expect(BookingStatus.pending, equals('pending'));
      expect(BookingStatus.confirmed, equals('confirmed'));
      expect(BookingStatus.checkedIn, equals('checked-in'));
      expect(BookingStatus.completed, equals('completed'));
      expect(BookingStatus.cancelled, equals('cancelled'));
      expect(BookingStatus.expired, equals('expired'));
      expect(BookingStatus.noShow, equals('no-show'));
    });

    test('isValid returns true for valid statuses', () {
      expect(BookingStatus.isValid(BookingStatus.pending), isTrue);
      expect(BookingStatus.isValid(BookingStatus.confirmed), isTrue);
      expect(BookingStatus.isValid(BookingStatus.completed), isTrue);
    });

    test('isValid returns false for invalid statuses', () {
      expect(BookingStatus.isValid('invalid'), isFalse);
      expect(BookingStatus.isValid('unknown'), isFalse);
    });

    test('getStatusText returns correct Thai text', () {
      expect(BookingStatus.getStatusText(BookingStatus.pending), 
             equals('รอการยืนยัน QR'));
      expect(BookingStatus.getStatusText(BookingStatus.confirmed), 
             equals('ยืนยัน QR แล้ว'));
      expect(BookingStatus.getStatusText(BookingStatus.completed), 
             equals('เสร็จสิ้น'));
    });

    test('getStatusColor returns correct color', () {
      expect(BookingStatus.getStatusColor(BookingStatus.pending), 
             equals('orange'));
      expect(BookingStatus.getStatusColor(BookingStatus.confirmed), 
             equals('blue'));
      expect(BookingStatus.getStatusColor(BookingStatus.completed), 
             equals('green'));
    });

    test('canBeCancelled returns correct value', () {
      expect(BookingStatus.canBeCancelled(BookingStatus.pending), isTrue);
      expect(BookingStatus.canBeCancelled(BookingStatus.confirmed), isTrue);
      expect(BookingStatus.canBeCancelled(BookingStatus.completed), isFalse);
      expect(BookingStatus.canBeCancelled(BookingStatus.cancelled), isFalse);
    });

    test('canBeCheckedIn returns correct value', () {
      expect(BookingStatus.canBeCheckedIn(BookingStatus.confirmed), isTrue);
      expect(BookingStatus.canBeCheckedIn(BookingStatus.pending), isFalse);
      expect(BookingStatus.canBeCheckedIn(BookingStatus.completed), isFalse);
    });

    test('isActive returns correct value', () {
      expect(BookingStatus.isActive(BookingStatus.pending), isTrue);
      expect(BookingStatus.isActive(BookingStatus.confirmed), isTrue);
      expect(BookingStatus.isActive(BookingStatus.checkedIn), isTrue);
      expect(BookingStatus.isActive(BookingStatus.completed), isFalse);
      expect(BookingStatus.isActive(BookingStatus.cancelled), isFalse);
    });
  });

  group('ActivityRequestStatus Tests', () {
    test('All status constants are defined', () {
      expect(ActivityRequestStatus.pending, equals('pending'));
      expect(ActivityRequestStatus.approved, equals('approved'));
      expect(ActivityRequestStatus.rejected, equals('rejected'));
    });

    test('getStatusText returns correct Thai text', () {
      expect(ActivityRequestStatus.getStatusText(ActivityRequestStatus.pending),
             equals('รอการอนุมัติ'));
      expect(ActivityRequestStatus.getStatusText(ActivityRequestStatus.approved),
             equals('อนุมัติแล้ว'));
      expect(ActivityRequestStatus.getStatusText(ActivityRequestStatus.rejected),
             equals('ปฏิเสธ'));
    });

    test('getStatusColor returns correct color', () {
      expect(ActivityRequestStatus.getStatusColor(ActivityRequestStatus.pending),
             equals('orange'));
      expect(ActivityRequestStatus.getStatusColor(ActivityRequestStatus.approved),
             equals('green'));
      expect(ActivityRequestStatus.getStatusColor(ActivityRequestStatus.rejected),
             equals('red'));
    });
  });

  group('BookingType Tests', () {
    test('All type constants are defined', () {
      expect(BookingType.regular, equals('regular'));
      expect(BookingType.activity, equals('activity'));
    });

    test('isValid returns correct value', () {
      expect(BookingType.isValid(BookingType.regular), isTrue);
      expect(BookingType.isValid(BookingType.activity), isTrue);
      expect(BookingType.isValid('invalid'), isFalse);
    });

    test('getTypeText returns correct Thai text', () {
      expect(BookingType.getTypeText(BookingType.regular),
             equals('จองทั่วไป'));
      expect(BookingType.getTypeText(BookingType.activity),
             equals('จองกิจกรรม'));
    });
  });

  group('CourtType Tests', () {
    test('All type constants are defined', () {
      expect(CourtType.outdoor, equals('outdoor'));
      expect(CourtType.indoor, equals('indoor'));
    });

    test('getTypeText returns correct Thai text', () {
      expect(CourtType.getTypeText(CourtType.outdoor),
             equals('สนามกลางแจ้ง'));
      expect(CourtType.getTypeText(CourtType.indoor),
             equals('สนามในร่ม'));
    });
  });

  group('SportCategory Tests', () {
    test('All category constants are defined', () {
      expect(SportCategory.football, equals('football'));
      expect(SportCategory.basketball, equals('basketball'));
      expect(SportCategory.volleyball, equals('volleyball'));
    });

    test('getCategoryText returns correct Thai text', () {
      expect(SportCategory.getCategoryText(SportCategory.football),
             equals('ฟุตบอล'));
      expect(SportCategory.getCategoryText(SportCategory.basketball),
             equals('บาสเกตบอล'));
      expect(SportCategory.getCategoryText(SportCategory.volleyball),
             equals('วอลเลย์บอล'));
    });

    test('isValid returns correct value', () {
      expect(SportCategory.isValid(SportCategory.football), isTrue);
      expect(SportCategory.isValid('invalid'), isFalse);
    });
  });

  group('TimeSlot Tests', () {
    test('Standard slots are defined correctly', () {
      expect(TimeSlot.standardSlots.length, equals(7));
      expect(TimeSlot.standardSlots.first, equals('08:00-10:00'));
      expect(TimeSlot.standardSlots.last, equals('20:00-22:00'));
    });
  });
}
