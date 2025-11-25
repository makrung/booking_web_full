import 'package:flutter/material.dart';
import '../services/auth_state_manager.dart';
import '../services/auth_service.dart';

class PersistentAuthWrapper extends StatefulWidget {
  final Widget child;
  final String? targetRoute;
  final bool requireAuth;
  final bool requireAdmin;

  const PersistentAuthWrapper({
    Key? key,
    required this.child,
    this.targetRoute,
    this.requireAuth = false,
    this.requireAdmin = false,
  }) : super(key: key);

  @override
  _PersistentAuthWrapperState createState() => _PersistentAuthWrapperState();
}

class _PersistentAuthWrapperState extends State<PersistentAuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAndMaintainAuth();
  }

  Future<void> _checkAndMaintainAuth() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // ตรวจสอบ auth state
      final isLoggedIn = await AuthService.isLoggedIn();
      final isAdmin = await AuthService.isAdmin();

      setState(() {
        _isAuthenticated = isLoggedIn;
        _isAdmin = isAdmin;
        _isLoading = false;
      });

      // ถ้าต้องการ auth แต่ไม่ได้ล็อกอิน หรือต้องการ admin แต่ไม่ใช่ admin
      if (widget.requireAuth && !isLoggedIn) {
        _redirectToHome();
      } else if (widget.requireAdmin && !isAdmin) {
        _redirectToHome();
      }

      // อัปเดต auth state manager
      await AuthStateManager().refreshAuthState();
    } catch (e) {
      print('PersistentAuthWrapper: Error checking auth: $e');
      setState(() {
        _isAuthenticated = false;
        _isAdmin = false;
        _isLoading = false;
      });

      if (widget.requireAuth || widget.requireAdmin) {
        _redirectToHome();
      }
    }
  }

  void _redirectToHome() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
              SizedBox(height: 16),
              Text(
                'กำลังตรวจสอบการเข้าสู่ระบบ...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ถ้าต้องการ auth แต่ไม่ได้ล็อกอิน
    if (widget.requireAuth && !_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'กรุณาเข้าสู่ระบบ',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: Text('ไปหน้าเข้าสู่ระบบ'),
              ),
            ],
          ),
        ),
      );
    }

    // ถ้าต้องการ admin แต่ไม่ใช่ admin
    if (widget.requireAdmin && !_isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'ไม่มีสิทธิ์เข้าถึงหน้านี้',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'ต้องเป็นผู้ดูแลระบบเท่านั้น',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: Text('กลับหน้าหลัก'),
              ),
            ],
          ),
        ),
      );
    }

    // ถ้าผ่านการตรวจสอบทั้งหมดแล้ว แสดงหน้าที่ต้องการ
    return widget.child;
  }
}