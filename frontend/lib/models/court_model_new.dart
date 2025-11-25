class CourtLocation {
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? description;

  CourtLocation({
    this.latitude,
    this.longitude,
    this.address,
    this.description,
  });

  factory CourtLocation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CourtLocation();
    
    return CourtLocation(
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      address: json['address'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'description': description,
    };
  }
}

class Court {
  final String id;
  final String name;
  final String type; // 'outdoor' หรือ 'indoor'
  final String category; // เช่น 'tennis', 'badminton', etc.
  final int number; // หมายเลขสนาม
  final bool isActivityOnly; // สำหรับลานอเนกประสงค์
  final String openBookingTime; // เวลาเปิดรับจอง
  final String playStartTime; // เวลาเริ่มเล่น
  final String playEndTime; // เวลาปิดสนาม
  final bool isAvailable;
  final CourtLocation? location; // ตำแหน่งสนาม

  Court({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.number,
    this.isActivityOnly = false,
    required this.openBookingTime,
    required this.playStartTime,
    required this.playEndTime,
    this.isAvailable = true,
    this.location,
  });

  factory Court.fromJson(Map<String, dynamic> json) {
    return Court(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      category: json['category'] ?? '',
      number: json['number'] ?? 1,
      isActivityOnly: json['isActivityOnly'] ?? false,
      openBookingTime: json['openBookingTime'] ?? '09:00',
      playStartTime: json['playStartTime'] ?? '12:00',
      playEndTime: json['playEndTime'] ?? '22:00',
      isAvailable: json['isAvailable'] ?? true,
      location: CourtLocation.fromJson(json['location']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'category': category,
      'number': number,
      'isActivityOnly': isActivityOnly,
      'openBookingTime': openBookingTime,
      'playStartTime': playStartTime,
      'playEndTime': playEndTime,
      'isAvailable': isAvailable,
      'location': location?.toJson(),
    };
  }

  // ตรวจสอบว่าเวลาที่เลือกอยู่ในช่วงที่เปิดให้เล่นหรือไม่
  bool isTimeSlotAvailable(String startTime, String endTime) {
    try {
      final playStart = _parseTime(playStartTime);
      final playEnd = _parseTime(playEndTime);
      final start = _parseTime(startTime);
      final end = _parseTime(endTime);
      
      return _isTimeInRange(start, playStart, playEnd) && 
             _isTimeInRange(end, playStart, playEnd);
    } catch (e) {
      return false;
    }
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  bool _isTimeInRange(DateTime time, DateTime start, DateTime end) {
    return (time.isAfter(start) || time.isAtSameMomentAs(start)) &&
           (time.isBefore(end) || time.isAtSameMomentAs(end));
  }
}

// คลาสสำหรับจัดการข้อมูลสนาม
class CourtData {
  // ข้อมูลสนามจะมาจาก API แล้ว ไม่ต้องมี hardcode
  // ใช้สำหรับ utility functions เท่านั้น
  // ใช้ cache ในหน่วยความจำเพื่อให้บริการอื่นสามารถเข้าถึงข้อมูลสนามที่โหลดมาแล้วได้
  static final List<Court> _cachedCourts = [];

  // ตั้งค่าข้อมูลสนามจาก JSON ที่ได้จาก API (optional helper)
  static void setCourtsFromJson(List<dynamic> courtsJson) {
    _cachedCourts
      ..clear()
      ..addAll(
        courtsJson
            .whereType<Map<String, dynamic>>()
            .map((e) => Court.fromJson(e)),
      );
  }

  // ตั้งค่าข้อมูลสนามจากโมเดลโดยตรง
  static void setCourts(List<Court> courts) {
    _cachedCourts
      ..clear()
      ..addAll(courts);
  }

  // ดึงข้อมูลสนามทั้งหมดจาก cache (อาจว่างได้ถ้ายังไม่เคยตั้งค่า)
  static List<Court> getAllCourts() {
    return List.unmodifiable(_cachedCourts);
  }

  // ดึงสนามตามประเภท
  static List<Court> getCourtsByType(String type) {
    return _cachedCourts.where((c) => c.type == type).toList(growable: false);
  }

  // ดึงสนามตามหมวดหมู่
  static List<Court> getCourtsByCategory(String category) {
    return _cachedCourts
        .where((c) => c.category == category)
        .toList(growable: false);
  }

  // ดึงข้อมูลสนามตาม id
  static Court? getCourtById(String id) {
    for (final c in _cachedCourts) {
      if (c.id == id) return c;
    }
    return null;
  }
  
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

  // สร้างรายการเวลาสำหรับการจอง (1 ชั่วโมงต่อช่วง)
  static List<String> generateTimeSlots(String startTime, String endTime) {
    final slots = <String>[];
    
    try {
      final start = _parseTime(startTime);
      final end = _parseTime(endTime);
      
      DateTime current = start;
      while (current.isBefore(end)) {
        final next = current.add(Duration(hours: 1));
        if (next.isAfter(end)) break;
        
        final timeStr = '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}-${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
        slots.add(timeStr);
        current = next;
      }
    } catch (e) {
      // Return empty list if parsing fails
    }
    
    return slots;
  }

  static DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  // ตรวจสอบว่าสามารถจองได้หรือไม่ (ตรวจเวลาปัจจุบันกับเวลาเปิดจอง)
  static bool canBookNow(String openBookingTime) {
    try {
      final now = DateTime.now();
      final openTime = _parseTime(openBookingTime);
      final currentTime = DateTime(2000, 1, 1, now.hour, now.minute);
      
      return currentTime.isAfter(openTime) || currentTime.isAtSameMomentAs(openTime);
    } catch (e) {
      return false;
    }
  }

  // แปลงหมวดหมู่เป็นไอคอน
  static String getCategoryIcon(String category) {
    switch (category) {
      case 'tennis': return '🎾';
      case 'basketball': return '🏀';
      case 'badminton': return '🏸';
      case 'futsal': return '⚽';
      case 'football': return '⚽';
      case 'volleyball': return '🏐';
      case 'takraw': return '🥎';
      case 'multipurpose': return '🏟️';
      default: return '🏃';
    }
  }
}