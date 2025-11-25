import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';
import '../widgets/map_location_picker.dart';
import 'dart:math' as math;
import 'court_management_service_new.dart' as CourtAPI;
import 'content_service.dart';

class EnhancedLocationService {
  static const String _isTestModeKey = 'location_test_mode';
  static const String _testLocationLatKey = 'test_location_lat';
  static const String _testLocationLngKey = 'test_location_lng';
  static const String _manualLocationModeKey = 'manual_location_mode';

  // เปิด/ปิดโหมดทดสอบ (สำหรับ admin)
  static Future<bool> isTestModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isTestModeKey) ?? false;
  }

  static Future<void> setTestMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isTestModeKey, enabled);
  }

  // เปิด/ปิดโหมดเลือกตำแหน่งด้วยตนเอง
  static Future<bool> isManualLocationModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_manualLocationModeKey) ?? false; // ปิดโดยค่าเริ่มต้น เพื่อบังคับใช้ GPS
  }

  static Future<void> setManualLocationMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_manualLocationModeKey, enabled);
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

  // ดึงตำแหน่งปัจจุบันจาก GPS
  static Future<UserLocation?> getCurrentLocationFromGPS() async {
    try {
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
      print('Error getting GPS location: $e');
      return null;
    }
  }

  // เลือกตำแหน่งจากแผนที่
  static Future<UserLocation?> selectLocationFromMap(
    BuildContext context, {
    LatLng? initialLocation,
    String title = 'เลือกตำแหน่งสนาม',
  }) async {
    try {
      final LatLng? selectedLocation = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          builder: (context) => MapLocationPicker(
            initialLocation: initialLocation,
            title: title,
            onLocationSelected: (location) {
              // Callback เมื่อเลือกตำแหน่ง
            },
          ),
        ),
      );

      if (selectedLocation != null) {
        return UserLocation(
          latitude: selectedLocation.latitude,
          longitude: selectedLocation.longitude,
          timestamp: DateTime.now(),
          accuracy: 1.0, // ความแม่นยำสูง (เลือกเอง)
        );
      }
      return null;
    } catch (e) {
      print('Error selecting location from map: $e');
      return null;
    }
  }

  // ดึงตำแหน่งปัจจุบัน (รวมทั้ง GPS และแผนที่)
  static Future<UserLocation?> getCurrentLocation(BuildContext? context) async {
    try {
      // ตรวจสอบโหมดทดสอบ
      if (await isTestModeEnabled()) {
        return await getTestLocation();
      }

      // ตรวจสอบโหมดเลือกตำแหน่งด้วยตนเอง
      bool isManualMode = await isManualLocationModeEnabled();
      
      if (isManualMode && context != null) {
        return await _showLocationSelectionDialog(context);
      } else {
        return await getCurrentLocationFromGPS();
      }
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // แสดง Dialog ให้เลือกวิธีการหาตำแหน่ง
  static Future<UserLocation?> _showLocationSelectionDialog(BuildContext context) async {
    return await showDialog<UserLocation>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_on, color: Colors.teal[700]),
              SizedBox(width: 8),
              Text('เลือกวิธีการหาตำแหน่ง'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'กรุณาเลือกวิธีการที่คุณต้องการใช้ในการระบุตำแหน่ง',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              _buildLocationOptionCard(
                context: context,
                icon: Icons.gps_fixed,
                title: 'ใช้ GPS',
                subtitle: 'ตรวจจับตำแหน่งอัตโนมัติ',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(context); // ปิด dialog
                  final location = await getCurrentLocationFromGPS();
                  Navigator.pop(context, location); // ส่งผลลัพธ์กลับ
                },
              ),
              SizedBox(height: 12),
              _buildLocationOptionCard(
                context: context,
                icon: Icons.map,
                title: 'เลือกจากแผนที่',
                subtitle: 'ปักหมุดตำแหน่งด้วยตนเอง',
                color: Colors.green,
                onTap: () async {
                  Navigator.pop(context); // ปิด dialog
                  final location = await selectLocationFromMap(context);
                  Navigator.pop(context, location); // ส่งผลลัพธ์กลับ
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('ยกเลิก'),
              onPressed: () => Navigator.pop(context, null),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildLocationOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ตรวจสอบว่าอยู่ในสนามที่กำหนดหรือไม่
  static Future<bool> isWithinCourtArea(
    UserLocation userLocation,
    CourtLocation courtLocation,
    {double radiusInMeters = 50.0}
  ) async {
    double distance = calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      courtLocation.latitude,
      courtLocation.longitude,
    );
    
    return distance <= radiusInMeters;
  }

  // คำนวณระยะทางระหว่างจุดสองจุด (เมตร)
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // รัศมีโลกเป็นเมตร
    
    double dLat = _toRadians(lat2 - lat1);
    double dLng = _toRadians(lng2 - lng1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Format distance nicely: show meters under 1000, otherwise show kilometers with 2 decimals
  static String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} เมตร';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(2)} กม.';
  }

  // แปลง LatLng เป็น UserLocation
  static UserLocation latLngToUserLocation(LatLng latLng) {
    return UserLocation(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      timestamp: DateTime.now(),
      accuracy: 1.0,
    );
  }

  // แปลง UserLocation เป็น LatLng
  static LatLng userLocationToLatLng(UserLocation location) {
    return LatLng(location.latitude, location.longitude);
  }

  // ข้อมูลสนามตัวอย่างของมหาวิทยาลัยศิลปากร วิทยาเขตสนามจันทร์
  static List<Map<String, dynamic>> getSampleCourtLocations() {
    return [
      {
        'name': 'สนามฟุตบอล 1',
        'location': LatLng(13.8199, 100.0433),
        'type': 'outdoor',
        'category': 'football',
      },
      {
        'name': 'สนามบาสเกตบอล 1',
        'location': LatLng(13.8205, 100.0436),
        'type': 'outdoor',
        'category': 'basketball',
      },
      {
        'name': 'สนามเทนนิส 1',
        'location': LatLng(13.8201, 100.0440),
        'type': 'outdoor',
        'category': 'tennis',
      },
      {
        'name': 'สนามแบดมินตัน (ในร่ม)',
        'location': LatLng(13.8195, 100.0428),
        'type': 'indoor',
        'category': 'badminton',
      },
    ];
  }

  // ตรวจสอบตำแหน่งสนาม
  static Future<Map<String, dynamic>> verifyCourtLocation(String courtId, BuildContext? context) async {
    try {
      // บังคับใช้ตำแหน่งจาก GPS เท่านั้น (ไม่ให้เลือกเอง)
      final userLocation = await getCurrentLocationFromGPS();
      if (userLocation == null) {
        return {
          'success': false,
          'message': 'ไม่สามารถดึงตำแหน่งปัจจุบันได้',
        };
      }

      print('📍 User Location: ${userLocation.latitude}, ${userLocation.longitude}');
      print('🎯 Accuracy: ${userLocation.accuracy} meters');
      print('⏰ Timestamp: ${userLocation.timestamp}');

      // ดึงตำแหน่งสนามจาก Firestore ผ่าน Backend API
      Map<String, dynamic>? court;
      try {
        final resp = await CourtAPI.CourtManagementService.getCourt(courtId);
        court = resp['court'] as Map<String, dynamic>?;
      } catch (e) {
        print('Error fetching court from API: $e');
      }

      final location = court != null ? (court['location'] as Map<String, dynamic>?) : null;
      final double? courtLat = (location?['latitude'] as num?)?.toDouble();
      final double? courtLng = (location?['longitude'] as num?)?.toDouble();

      if (courtLat == null || courtLng == null) {
        return {
          'success': false,
          'message': 'ไม่พบพิกัดของสนามจากฐานข้อมูล',
        };
      }

      print('🏟️  Court Location: $courtLat, $courtLng');

      // อ่านค่ารัศมีจากการตั้งค่าของระบบ (admin) หากไม่มีให้ใช้ค่าเริ่มต้น 60 เมตร
      double radiusMeters = 60.0;
      try {
        final s = await ContentService.getContent('court_verification_radius_meters');
        if (s != null && s.isNotEmpty) {
          final parsed = double.tryParse(s);
          if (parsed != null && parsed > 0) radiusMeters = parsed;
        }
      } catch (e) {
        print('Error reading court_verification_radius_meters: $e');
      }

  final distance = userLocation.distanceTo(courtLat, courtLng);
  final formattedDistance = _formatDistance(distance);
  final formattedRadius = radiusMeters < 1000 ? '${radiusMeters.toStringAsFixed(0)} เมตร' : '${(radiusMeters/1000.0).toStringAsFixed(2)} กม.';
  print('📏 Distance: ${distance.toStringAsFixed(2)} meters (limit: ${radiusMeters.toStringAsFixed(2)} m)');
      
      final isWithinRadius = distance <= radiusMeters;

      if (isWithinRadius) {
        print('✅ Within radius - Check-in allowed');
        return {
          'success': true,
          'message': 'ยืนยันตำแหน่งสำเร็จ',
          'userLocation': userLocation.toJson(),
          'courtLocation': {
            'courtId': courtId,
            'courtName': court?['name'] ?? 'ไม่ทราบ',
            'latitude': courtLat,
            'longitude': courtLng,
            'radiusMeters': radiusMeters,
          },
          'distanceMeters': distance,
        };
      } else {
        return {
          'success': false,
          // ให้ข้อความอธิบายค่าระยะทางจริงและค่าที่ระบบกำหนดไว้
          // ให้ข้อความอธิบายค่าระยะทางจริงและค่าที่ระบบกำหนดไว้ (จัดหน่วยอัตโนมัติ)
          'message': 'คุณไม่ได้อยู่ในบริเวณสนาม (ห่าง $formattedDistance — เกิน $formattedRadius)',
          'userLocation': userLocation.toJson(),
          'courtLocation': {
            'courtId': courtId,
            'courtName': court?['name'] ?? 'ไม่ทราบ',
            'latitude': courtLat,
            'longitude': courtLng,
            'radiusMeters': radiusMeters,
          },
          'distanceMeters': distance,
        };
      }
    } catch (e) {
      print('Error verifying court location: $e');
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการตรวจสอบตำแหน่ง: ${e.toString()}',
      };
    }
  }

    // สร้างปุ่มรีเฟรชตำแหน่ง: จะขอสิทธิ์ ถามให้เปิด GPS หากปิด และดึงตำแหน่งใหม่
    // onRefreshed จะถูกเรียกด้วย UserLocation? (null เมื่อไม่สำเร็จ)
    static Widget buildRefreshLocationButton({
      required BuildContext context,
      required ValueChanged<UserLocation?> onRefreshed,
      String label = 'รีเฟรชตำแหน่ง',
    }) {
      return ElevatedButton.icon(
        icon: Icon(Icons.refresh),
        label: Text(label),
        onPressed: () async {
          // แสดง loading dialog ระหว่างรอดึงพิกัด
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => Center(child: CircularProgressIndicator()),
          );

          try {
            // ตรวจสอบสิทธิ์
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }

            if (permission == LocationPermission.deniedForever) {
              Navigator.pop(context); // ปิด loading
              final open = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('ต้องการเปิดการตั้งค่า'),
                  content: Text('แอปไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง โปรดเปิดสิทธิ์ในการตั้งค่าแอป'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('ยกเลิก')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('ไปที่การตั้งค่า')),
                  ],
                ),
              );
              if (open == true) await Geolocator.openAppSettings();
              onRefreshed(null);
              return;
            }

            // ยังไม่ได้รับสิทธิ์
            if (!(permission == LocationPermission.whileInUse || permission == LocationPermission.always)) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่ได้รับสิทธิ์การเข้าถึงตำแหน่ง')));
              onRefreshed(null);
              return;
            }

            // ตรวจสอบว่า GPS เปิดอยู่
            final serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
              Navigator.pop(context);
              final openLoc = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('เปิด GPS'),
                  content: Text('กรุณาเปิด GPS เพื่อให้ระบบสามารถตรวจจับตำแหน่งได้'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('ยกเลิก')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('ไปที่การตั้งค่า')),
                  ],
                ),
              );
              if (openLoc == true) await Geolocator.openLocationSettings();
              onRefreshed(null);
              return;
            }

            // ดึงตำแหน่งปัจจุบัน
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            );

            final newLoc = UserLocation(
              latitude: pos.latitude,
              longitude: pos.longitude,
              timestamp: DateTime.now(),
              accuracy: pos.accuracy,
            );

            Navigator.pop(context); // ปิด loading
            onRefreshed(newLoc);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('รีเฟรชตำแหน่งเรียบร้อย')));
          } catch (e) {
            Navigator.pop(context); // ปิด loading
            print('Error refreshing location: $e');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดระหว่างรีเฟรชตำแหน่ง')));
            onRefreshed(null);
          }
        },
      );
    }

  // รีเซ็ตการตั้งค่า
  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isTestModeKey);
    await prefs.remove(_testLocationLatKey);
    await prefs.remove(_testLocationLngKey);
    await prefs.remove(_manualLocationModeKey);
  }
}