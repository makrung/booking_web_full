import 'dart:math' as math;

class UserLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      accuracy: json['accuracy']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
    };
  }

  // ตรวจสอบว่าอยู่ในรัศมีที่กำหนดหรือไม่
  bool isWithinRadius(double targetLat, double targetLng, double radiusInMeters) {
    final distance = _calculateDistance(latitude, longitude, targetLat, targetLng);
    return distance <= radiusInMeters;
  }

  // คำนวณระยะทางถึงจุดหมาย (public method)
  double distanceTo(double targetLat, double targetLng) {
    return _calculateDistance(latitude, longitude, targetLat, targetLng);
  }

  // คำนวณระยะทางระหว่างจุดสองจุด (Haversine formula)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadiusKm = 6371;
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadiusKm * c * 1000; // แปลงเป็นเมตร
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}

class CourtLocation {
  final String courtId;
  final String courtName;
  final double latitude;
  final double longitude;
  final double verificationRadiusMeters;

  CourtLocation({
    required this.courtId,
    required this.courtName,
    required this.latitude,
    required this.longitude,
    this.verificationRadiusMeters = 50.0, // รัศมี 50 เมตร
  });

  static List<CourtLocation> getCourtLocations() {
    return [
      // สนามเทนนิส
      CourtLocation(
        courtId: 'outdoor_tennis_1',
        courtName: 'เทนนิส-สนามที่ 1',
        latitude: 13.8199, // พิกัดจำลองมหาวิทยาลัยศิลปกรรม
        longitude: 100.0438,
      ),
      CourtLocation(
        courtId: 'outdoor_tennis_2',
        courtName: 'เทนนิส-สนามที่ 2',
        latitude: 13.8200,
        longitude: 100.0439,
      ),
      CourtLocation(
        courtId: 'outdoor_tennis_3',
        courtName: 'เทนนิส-สนามที่ 3',
        latitude: 13.8201,
        longitude: 100.0440,
      ),
      CourtLocation(
        courtId: 'outdoor_tennis_4',
        courtName: 'เทนนิส-สนามที่ 4',
        latitude: 13.8202,
        longitude: 100.0441,
      ),
      
      // สนามบาสเกตบอล
      CourtLocation(
        courtId: 'outdoor_basketball_1',
        courtName: 'บาสเกตบอล-สนามที่ 1',
        latitude: 13.8203,
        longitude: 100.0442,
      ),
      
      // สนามฟุตซอล
      CourtLocation(
        courtId: 'outdoor_futsal_1',
        courtName: 'ฟุตซอล-สนามที่ 1',
        latitude: 13.8204,
        longitude: 100.0443,
      ),
      CourtLocation(
        courtId: 'outdoor_futsal_2',
        courtName: 'ฟุตซอล-สนามที่ 2',
        latitude: 13.8205,
        longitude: 100.0444,
      ),
      CourtLocation(
        courtId: 'outdoor_futsal_3',
        courtName: 'ฟุตซอล-สนามที่ 3',
        latitude: 13.8206,
        longitude: 100.0445,
      ),
      
      // สนามอเนกประสงค์
      CourtLocation(
        courtId: 'outdoor_multipurpose_1',
        courtName: 'ลานอเนกประสงค์',
        latitude: 13.8207,
        longitude: 100.0446,
      ),
      
      // สนามตะกร้อ
      CourtLocation(
        courtId: 'outdoor_takraw_1',
        courtName: 'ตะกร้อ-สนามที่ 1',
        latitude: 13.8208,
        longitude: 100.0447,
      ),
      CourtLocation(
        courtId: 'outdoor_takraw_2',
        courtName: 'ตะกร้อ-สนามที่ 2',
        latitude: 13.8209,
        longitude: 100.0448,
      ),
      
      // สนามฟุตบอล
      CourtLocation(
        courtId: 'outdoor_football_1',
        courtName: 'ฟุตบอล-สนามที่ 1',
        latitude: 13.8210,
        longitude: 100.0449,
      ),
      
      // สนามแบดมินตัน (ในร่ม)
      CourtLocation(
        courtId: 'indoor_badminton_1',
        courtName: 'แบดมินตัน-สนามที่ 1',
        latitude: 13.8211,
        longitude: 100.0450,
      ),
      CourtLocation(
        courtId: 'indoor_badminton_2',
        courtName: 'แบดมินตัน-สนามที่ 2',
        latitude: 13.8212,
        longitude: 100.0451,
      ),
      CourtLocation(
        courtId: 'indoor_badminton_3',
        courtName: 'แบดมินตัน-สนามที่ 3',
        latitude: 13.8213,
        longitude: 100.0452,
      ),
      CourtLocation(
        courtId: 'indoor_badminton_4',
        courtName: 'แบดมินตัน-สนามที่ 4',
        latitude: 13.8214,
        longitude: 100.0453,
      ),
      CourtLocation(
        courtId: 'indoor_badminton_5',
        courtName: 'แบดมินตัน-สนามที่ 5',
        latitude: 13.8215,
        longitude: 100.0454,
      ),
      CourtLocation(
        courtId: 'indoor_badminton_6',
        courtName: 'แบดมินตัน-สนามที่ 6',
        latitude: 13.8216,
        longitude: 100.0455,
      ),
      
      // สนามบาสเกตบอล (ในร่ม)
      CourtLocation(
        courtId: 'indoor_basketball_1',
        courtName: 'บาสเกตบอล-สนามในร่ม',
        latitude: 13.8217,
        longitude: 100.0456,
      ),
      
      // สนามวอลเลย์บอล
      CourtLocation(
        courtId: 'indoor_volleyball_1',
        courtName: 'วอลเลย์บอล-สนามที่ 1',
        latitude: 13.8218,
        longitude: 100.0457,
      ),
    ];
  }

  static CourtLocation? getCourtLocation(String courtId) {
    try {
      return getCourtLocations().firstWhere((court) => court.courtId == courtId);
    } catch (e) {
      return null;
    }
  }
}
