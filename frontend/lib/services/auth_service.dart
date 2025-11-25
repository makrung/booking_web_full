import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userDataKey = 'user_data';
  static Map<String, dynamic>? _lastUser;
  static DateTime? _lastUserAt;
  
  // ตรวจสอบว่า user ล็อกอินอยู่หรือไม่
  static Future<bool> isLoggedIn() async {
    try {
      print('AuthService: กำลังตรวจสอบ token...');
      final token = await ApiService.getToken();
      
      if (token == null || token.isEmpty) {
        print('AuthService: ไม่พบ token');
        await _clearAuthData(); // ล้างข้อมูลเก่าถ้าไม่มี token
        return false;
      }
      
      print('AuthService: พบ token, กำลังตรวจสอบกับ server...');
      // ตรวจสอบ token กับ server
      final result = await ApiService.verifyToken();
      final isValid = result['success'] ?? false;
      print('AuthService: ผลการตรวจสอบ: $isValid');
      
      if (!isValid) {
        // หากเป็นข้อผิดพลาดเครือข่าย (statusCode==0) ให้ถือว่า token ยังไม่แน่ชัด อย่าล้างข้อมูลทันที
        final sc = result['statusCode'] is int ? result['statusCode'] as int : -1;
        if (sc == 0 || sc == 429 || sc >= 500) {
          print('AuthService: การเชื่อมต่อขัดข้อง ชะลอการล้าง token ชั่วคราว');
          return true; // ยอมให้ผ่านชั่วคราว เพื่อลดอาการเด้งหลุด
        }
        print('AuthService: Token หมดอายุหรือไม่ถูกต้อง, ลบข้อมูลการล็อกอิน');
        await _clearAuthData();
      }
      // อัปเดต cache ผู้ใช้ถ้าระบุมา
      if (isValid && result['user'] != null) {
        _lastUser = Map<String, dynamic>.from(result['user']);
        _lastUserAt = DateTime.now();
      }
      
      return isValid;
    } catch (e) {
      print('AuthService Error: $e');
      // อย่าล้างข้อมูลทันทีในกรณี error เครือข่าย ให้ถือว่ายังล็อกอินชั่วคราว
      return true;
    }
  }

  // ฟังก์ชันช่วยสำหรับล้างข้อมูล auth
  static Future<void> _clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userDataKey);
      await prefs.remove('userId');
      await prefs.remove('userEmail');
      await prefs.remove('userName');
      await prefs.remove('token');
      await prefs.remove('auth_token');
      await prefs.remove('user_role');
    } catch (e) {
      print('AuthService: Error clearing auth data: $e');
    }
  }
  
  // บันทึกสถานะการล็อกอิน
  static Future<void> setLoggedIn(bool status, [Map<String, dynamic>? userData]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, status);
    
    if (userData != null) {
      await prefs.setString(_userDataKey, userData.toString());
    }
  }
  
  // ลบสถานะการล็อกอิน
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // ลบข้อมูลทั้งหมดที่เกี่ยวข้อง
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userDataKey);
      await prefs.remove('userId');
      await prefs.remove('userEmail');
      await prefs.remove('userName');
      await prefs.remove('token');
      await prefs.remove('auth_token');
      await prefs.remove('user_role');
      
      print('AuthService: ลบข้อมูลการล็อกอินเรียบร้อยแล้ว');
      
      // เรียก API logout
      await ApiService.logout();
    } catch (e) {
      print('AuthService: Error during logout: $e');
    }
  }
  
  // ดึงข้อมูล user
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    // ใช้ cache ชั่วคราวเพื่อลดการยิง /auth/verify ถี่ๆ ภายใน 10 วินาที
    if (_lastUserAt != null && DateTime.now().difference(_lastUserAt!).inSeconds < 10) {
      return _lastUser;
    }
    final result = await ApiService.verifyToken();
    if (result['success']) {
      _lastUser = Map<String, dynamic>.from(result['user']);
      _lastUserAt = DateTime.now();
      return _lastUser;
    }
    return _lastUser; // ถ้า verify ไม่ผ่าน ให้คงค่าล่าสุดไว้ (จะถูกล้างเมื่อ isLoggedIn เคลียร์)
  }
  
  // ตรวจสอบว่าผู้ใช้เป็น admin หรือไม่
  static Future<bool> isAdmin() async {
    final user = await getCurrentUser();
    return user?['role'] == 'admin';
  }
  
  // ตรวจสอบและ redirect ถ้าไม่ได้ล็อกอิน
  static Future<bool> requireAuth() async {
    return await isLoggedIn();
  }
}
