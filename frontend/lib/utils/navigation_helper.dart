import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../Login.dart';
import '../widgets/auth_guard.dart';

class NavigationHelper {
  // นำทางแบบต้องมี auth
  static Future<void> navigateWithAuth(
    BuildContext context, 
    Widget destination,
  ) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    
    if (!isLoggedIn) {
      // แสดง dialog แจ้งให้ login
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.orange),
              SizedBox(width: 8),
              Text('ต้องเข้าสู่ระบบ'),
            ],
          ),
          content: Text('คุณต้องเข้าสู่ระบบก่อนเพื่อใช้งานฟีเจอร์นี้'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: Text('เข้าสู่ระบบ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }
    
    // ถ้า login แล้วให้ไปหน้าปลายทาง
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthGuard(
          requireAuth: true,
          child: destination,
        ),
      ),
    );
  }
  
  // นำทางแบบไม่ต้อง auth
  static void navigateWithoutAuth(
    BuildContext context, 
    Widget destination,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }
}
