import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import 'dart:math' as math;

class LocationService {
  static const String _isTestModeKey = 'location_test_mode';
  static const String _testLocationLatKey = 'test_location_lat';
  static const String _testLocationLngKey = 'test_location_lng';

  // เปิด/ปิดโหมดทดสอบ (สำหรับ admin)
  static Future<bool> isTestModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isTestModeKey) ?? false;
  }

  static Future<void> setTestMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isTestModeKey, enabled);
  }

  static Future<void> setTestLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_testLocationLatKey, lat);
    await prefs.setDouble(_testLocationLngKey, lng);
  }

  static Future<UserLocation?> getTestLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_testLocationLatKey);
    final lng = prefs.getDouble(_testLocationLngKey);
    
    if (lat != null && lng != null) {
      return UserLocation(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 1.0,
      );
    }
    return null;
  }

  // ขอสิทธิ์เข้าถึงตำแหน่ง
  static Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  // ตรวจสอบสิทธิ์
  static Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  // ดึงตำแหน่งปัจจุบัน
  static Future<UserLocation?> getCurrentLocation() async {
    try {
      // ตรวจสอบโหมดทดสอบ
      if (await isTestModeEnabled()) {
        return await getTestLocation();
      }

      // ตรวจสอบสิทธิ์
      if (!await hasLocationPermission()) {
        if (!await requestLocationPermission()) {
          throw Exception('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
        }
      }

      // ตรวจสอบว่า GPS เปิดอยู่หรือไม่
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('กรุณาเปิด GPS');
      }

      // ดึงตำแหน่ง
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        accuracy: position.accuracy,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // ตรวจสอบว่าอยู่ในสนามที่กำหนดหรือไม่
  static Future<Map<String, dynamic>> verifyCourtLocation(String courtId) async {
    try {
      // ตรวจสอบ test mode ก่อน
      final testMode = await isTestModeEnabled();
      if (testMode) {
        print('🧪 LocationService: Test mode enabled - skipping location verification');
        return {
          'success': true,
          'message': 'ยืนยันตำแหน่งสำเร็จ (โหมดทดสอบ)',
          'testMode': true,
        };
      }

      final userLocation = await getCurrentLocation();
      if (userLocation == null) {
        return {
          'success': false,
          'message': 'ไม่สามารถดึงตำแหน่งปัจจุบันได้',
        };
      }

      final courtLocation = CourtLocation.getCourtLocation(courtId);
      if (courtLocation == null) {
        return {
          'success': false,
          'message': 'ไม่พบข้อมูลตำแหน่งสนาม',
        };
      }

      final isWithinRadius = userLocation.isWithinRadius(
        courtLocation.latitude,
        courtLocation.longitude,
        courtLocation.verificationRadiusMeters,
      );

      if (isWithinRadius) {
        return {
          'success': true,
          'message': 'ยืนยันตำแหน่งสำเร็จ',
          'userLocation': userLocation.toJson(),
          'courtLocation': {
            'courtId': courtLocation.courtId,
            'courtName': courtLocation.courtName,
            'latitude': courtLocation.latitude,
            'longitude': courtLocation.longitude,
          },
        };
      } else {
        return {
          'success': false,
          'message': 'คุณไม่ได้อยู่ในบริเวณสนาม ${courtLocation.courtName}',
          'userLocation': userLocation.toJson(),
          'courtLocation': {
            'courtId': courtLocation.courtId,
            'courtName': courtLocation.courtName,
            'latitude': courtLocation.latitude,
            'longitude': courtLocation.longitude,
          },
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.toString()}',
      };
    }
  }

  // ดึงรายการสนามทั้งหมดพร้อมระยะทาง
  static Future<List<Map<String, dynamic>>> getCourtsWithDistance() async {
    try {
      final userLocation = await getCurrentLocation();
      if (userLocation == null) {
        return [];
      }

      final courts = CourtLocation.getCourtLocations();
      List<Map<String, dynamic>> courtsWithDistance = [];

      for (var court in courts) {
        final distance = _calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          court.latitude,
          court.longitude,
        );

        courtsWithDistance.add({
          'courtId': court.courtId,
          'courtName': court.courtName,
          'latitude': court.latitude,
          'longitude': court.longitude,
          'distance': distance,
          'isWithinRange': distance <= court.verificationRadiusMeters,
        });
      }

      // เรียงตามระยะทางใกล้ไกล
      courtsWithDistance.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double));

      return courtsWithDistance;
    } catch (e) {
      print('Error getting courts with distance: $e');
      return [];
    }
  }

  // คำนวณระยะทางระหว่างจุดสองจุด (Haversine formula)
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadiusKm = 6371;
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadiusKm * c * 1000; // แปลงเป็นเมตร
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
