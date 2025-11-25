import '../services/settings_service.dart';

class BookingType {
  static const String regular = 'regular'; // จองใช้งานทั่วไป
  static const String activity = 'activity'; // จองเพื่อกิจกรรม
}

class BookingRule {
  // จำกัดการจองต่อวัน
  static const int maxOutdoorBookingsPerDay = 1;
  static const int maxIndoorBookingsPerDay = 1;
  static const int maxHoursPerBooking = 1;
  
  // ระยะเวลาการจองล่วงหน้า (เดือน) - สำหรับกิจกรรม
  static const int maxAdvanceBookingMonths = 2;
  
  // เวลาปิดการจอง (22:00)
  static const String bookingCloseTime = '22:00';
  
  // เช็คว่าสามารถจองได้หรือไม่
  static Future<bool> canMakeBooking({
    required String bookingType, // 'regular' หรือ 'activity'
    required DateTime selectedDate,
    required String courtType, // 'outdoor' หรือ 'indoor'
    required List<Map<String, dynamic>> existingBookings,
    required String selectedTimeSlot,
  }) async {
    // ✅ เช็คโหมดทดสอบก่อน - หากเปิดโหมดทดสอบให้จองได้เสมอ
    final isTestMode = await SettingsService.isTestModeEnabled();
    if (isTestMode) {
      print('🧪 [BookingRule] Test mode enabled - bypassing all booking restrictions');
      return true; // ข้ามการตรวจสอบข้อจำกัดทั้งหมดในโหมดทดสอบ
    }

    // เช็คเวลาปิดการจอง (22:00)
    if (!(await isBookingTimeValid())) {
      return false;
    }

    // เช็ควันที่เลือก
    if (!(await isValidBookingDate(selectedDate, bookingType))) {
      return false;
    }

    // เช็คว่าเลยเวลาที่จองแล้วหรือไม่
    if (!(await isTimeSlotStillAvailable(selectedDate, selectedTimeSlot))) {
      return false;
    }

    // การจองปกติ - จองได้เฉพาะวันเดียว
    if (bookingType == BookingType.regular) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final selectedOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      
      if (!selectedOnly.isAtSameMomentAs(todayOnly)) {
        return false; // จองได้เฉพาะวันเดียว
      }
      
      // เช็คว่าผู้ใช้จองแล้วในวันนี้หรือยัง (จำกัด 1 ครั้งต่อวัน)
      if (hasBookingTodayAlready(existingBookings, selectedDate)) {
        return false;
      }
    }

    // เช็คการจองซ้ำในวันเดียวกัน
    if (hasConflictingBooking(
      selectedDate: selectedDate,
      courtType: courtType,
      existingBookings: existingBookings,
      selectedTimeSlot: selectedTimeSlot,
    )) {
      return false;
    }

    return true;
  }

  // เช็คว่าช่วงเวลายังจองได้หรือไม่ (ยังไม่เลยเวลามาแล้ว)
  static Future<bool> isTimeSlotStillAvailable(DateTime selectedDate, String timeSlot) async {
    // ✅ เช็คโหมดทดสอบก่อน - หากเปิดโหมดทดสอบให้จองได้ทุกเวลา
    final isTestMode = await SettingsService.isTestModeEnabled();
    if (isTestMode) {
      print('🧪 [BookingRule] Test mode enabled - all time slots available');
      return true;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    
    // ถ้าเป็นวันในอนาคต สามารถจองได้
    if (selectedDay.isAfter(today)) {
      return true;
    }
    
    // ถ้าเป็นวันในอดีต ไม่สามารถจองได้
    if (selectedDay.isBefore(today)) {
      return false;
    }
    
    // ถ้าเป็นวันปัจจุบัน ต้องเช็คเวลา
    final timeSlotParts = timeSlot.split('-');
    final startTimeStr = timeSlotParts[0];
    final timeParts = startTimeStr.split(':');
    final startHour = int.parse(timeParts[0]);
    final startMinute = int.parse(timeParts[1]);
    
    final currentTime = now.hour * 60 + now.minute;
    final timeSlotStart = startHour * 60 + startMinute;
    
    // ถ้าเวลาปัจจุบันเลยเวลาเริ่มต้นของช่วงการจองแล้ว จองไม่ได้
    return currentTime < timeSlotStart;
  }

  // เช็คว่าผู้ใช้จองในวันนี้แล้วหรือยัง
  static bool hasBookingTodayAlready(List<Map<String, dynamic>> existingBookings, DateTime selectedDate) {
    final selectedDateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    
    for (var booking in existingBookings) {
      final bookingDate = booking['date'];
      final status = booking['status'];
      
      // เช็คว่าเป็นวันเดียวกันและไม่ได้ยกเลิก (ไม่นับการจองที่ยกเลิกแล้ว)
      if (bookingDate == selectedDateStr && status != 'cancelled' && status != 'expired') {
        return true;
      }
    }
    
    return false;
  }

  // เช็คเวลาปิดการจอง
  static Future<bool> isBookingTimeValid() async {
    // ตรวจสอบ test mode ก่อน
    final isTestMode = await SettingsService.isTestModeEnabled();
    
    if (isTestMode) {
      return true; // อนุญาตให้จองได้ตลอดเวลาใน test mode
    }
    
    final now = DateTime.now();
    final closeTime = _parseTime(bookingCloseTime);
    final todayCloseTime = DateTime(
      now.year, 
      now.month, 
      now.day, 
      closeTime.hour, 
      closeTime.minute
    );
    
    return now.isBefore(todayCloseTime);
  }

  // เช็ควันที่สามารถจองได้
  static Future<bool> isValidBookingDate(DateTime selectedDate, String bookingType) async {
    // ✅ เช็คโหมดทดสอบก่อน - หากเปิดโหมดทดสอบให้จองได้ทุกวัน
    final isTestMode = await SettingsService.isTestModeEnabled();
    if (isTestMode) {
      print('🧪 [BookingRule] Test mode enabled - all dates are valid for booking');
      return true;
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selectedOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    
    // ไม่สามารถจองย้อนหลังได้
    if (selectedOnly.isBefore(todayOnly)) {
      return false;
    }

    // การจองปกติ - จองได้เฉพาะวันเดียว
    if (bookingType == BookingType.regular) {
      return selectedOnly.isAtSameMomentAs(todayOnly);
    }
    
    // การจองกิจกรรม - จองล่วงหน้าได้ 1-2 เดือน
    if (bookingType == BookingType.activity) {
      final minAdvanceDate = DateTime(today.year, today.month + 1, today.day);
      final maxAdvanceDate = DateTime(today.year, today.month + maxAdvanceBookingMonths, today.day);
      
      return selectedOnly.isAfter(minAdvanceDate.subtract(Duration(days: 1))) &&
             selectedOnly.isBefore(maxAdvanceDate.add(Duration(days: 1)));
    }

    return false;
  }

  // เช็คการจองซ้ำ
  static bool hasConflictingBooking({
    required DateTime selectedDate,
    required String courtType,
    required List<Map<String, dynamic>> existingBookings,
    required String selectedTimeSlot,
  }) {
    final selectedDateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    
    for (var booking in existingBookings) {
      final bookingDate = booking['date'];
      final bookingCourtType = booking['courtType'];
      final bookingTimeSlots = List<String>.from(booking['timeSlots'] ?? []);
      final status = booking['status'];
      
      // ข้ามการจองที่ยกเลิกแล้วหรือหมดเวลาแล้ว
      if (status == 'cancelled' || status == 'expired') {
        continue;
      }
      
      // เช็คว่าเป็นวันเดียวกันหรือไม่
      if (bookingDate == selectedDateStr) {
        // เช็คว่าเป็นประเภทสนามเดียวกันหรือไม่
        if (bookingCourtType == courtType) {
          // เช็คจำนวนการจองในประเภทสนามนี้แล้ว
          final maxBookings = courtType == 'outdoor' ? maxOutdoorBookingsPerDay : maxIndoorBookingsPerDay;
          if (maxBookings <= 1) {
            return true; // จองแล้ว 1 ครั้งในประเภทสนามนี้
          }
        }
        
        // เช็คเวลาทับซ้อนระหว่างกลางแจ้งกับในร่ม
        if (bookingCourtType != courtType && hasTimeOverlap(bookingTimeSlots, [selectedTimeSlot])) {
          return true; // เวลาทับซ้อนกัน
        }
      }
    }
    
    return false;
  }

  // เช็คเวลาทับซ้อน
  static bool hasTimeOverlap(List<String> timeSlots1, List<String> timeSlots2) {
    for (String slot1 in timeSlots1) {
      for (String slot2 in timeSlots2) {
        if (slot1 == slot2) {
          return true;
        }
        
        // เช็คเวลาที่ติดกัน
        final slot1Parts = slot1.split('-');
        final slot2Parts = slot2.split('-');
        
        if (slot1Parts.length == 2 && slot2Parts.length == 2) {
          final slot1Start = _parseTime(slot1Parts[0]);
          final slot1End = _parseTime(slot1Parts[1]);
          final slot2Start = _parseTime(slot2Parts[0]);
          final slot2End = _parseTime(slot2Parts[1]);
          
          // เช็คว่าเวลาทับซ้อนกันหรือไม่
          if (slot1Start.isBefore(slot2End) && slot2Start.isBefore(slot1End)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // แปลงเวลาจาก String เป็น DateTime
  static DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  // ได้ข้อความแสดงข้อผิดพลาด
  static Future<String> getBookingErrorMessage({
    required String bookingType,
    required DateTime selectedDate,
    required String courtType,
    required List<Map<String, dynamic>> existingBookings,
    required String selectedTimeSlot,
  }) async {
    // ✅ เช็คโหมดทดสอบก่อน - หากเปิดโหมดทดสอบไม่ควรมี error message
    final isTestMode = await SettingsService.isTestModeEnabled();
    if (isTestMode) {
      print('🧪 [BookingRule] Test mode enabled - no error message should be shown');
      return ''; // ไม่มี error message ในโหมดทดสอบ
    }

    // เช็คเวลาปิดการจอง
    if (!(await isBookingTimeValid())) {
      return 'ปิดการจองแล้ว กรุณาจองในเวลา 09:00-22:00 น.';
    }

    // เช็ควันที่
    if (!(await isValidBookingDate(selectedDate, bookingType))) {
      if (bookingType == BookingType.regular) {
        return 'การจองปกติสามารถจองได้เฉพาะวันเดียวเท่านั้น';
      } else {
        return 'การจองกิจกรรมต้องจองล่วงหน้า 1-2 เดือน';
      }
    }

    // เช็คเวลาที่เลยมาแล้ว
    if (!(await isTimeSlotStillAvailable(selectedDate, selectedTimeSlot))) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      
      if (selectedDay.isBefore(today)) {
        return 'ไม่สามารถจองย้อนหลังได้';
      } else {
        final timeSlotParts = selectedTimeSlot.split('-');
        final startTime = timeSlotParts[0];
        return 'ช่วงเวลา $startTime ผ่านไปแล้ว ไม่สามารถจองได้';
      }
    }

    // เช็คการจองในวันนี้แล้ว
    if (bookingType == BookingType.regular && hasBookingTodayAlready(existingBookings, selectedDate)) {
      return 'คุณได้จองสนามในวันนี้แล้ว (จำกัด 1 ครั้งต่อวัน)';
    }

    // เช็คการจองซ้ำ
    final selectedDateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    
    for (var booking in existingBookings) {
      final bookingDate = booking['date'];
      final bookingCourtType = booking['courtType'];
      final bookingTimeSlots = List<String>.from(booking['timeSlots'] ?? []);
      final status = booking['status'];
      
      // ข้ามการจองที่ยกเลิกแล้วหรือหมดเวลาแล้ว
      if (status == 'cancelled' || status == 'expired') continue;
      
      if (bookingDate == selectedDateStr) {
        if (bookingCourtType == courtType) {
          final courtTypeName = courtType == 'outdoor' ? 'สนามกลางแจ้ง' : 'สนามในร่ม';
          return 'คุณได้จอง$courtTypeNameแล้ว 1 ครั้งในวันนี้ (จำกัด 1 ครั้งต่อวัน)';
        }
        
        if (bookingCourtType != courtType && hasTimeOverlap(bookingTimeSlots, [selectedTimeSlot])) {
          final otherCourtType = bookingCourtType == 'outdoor' ? 'สนามกลางแจ้ง' : 'สนามในร่ม';
          return 'คุณได้จอง$otherCourtTypeในช่วงเวลาเดียวกันแล้ว';
        }
      }
    }

    return 'ไม่สามารถจองได้ กรุณาตรวจสอบข้อมูลอีกครั้ง';
  }
}
