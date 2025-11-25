import 'package:flutter/material.dart';
import '../services/auth_state_manager.dart';
import '../services/auth_service.dart';
import '../Homepage.dart';
import '../Login.dart';
import '../UserHomePage.dart';
import '../AdminDashboardPage.dart';

class RouteHandler extends StatefulWidget {
  final String routeName;
  
  const RouteHandler({
    Key? key,
    required this.routeName,
  }) : super(key: key);

  @override
  _RouteHandlerState createState() => _RouteHandlerState();
}

class _RouteHandlerState extends State<RouteHandler> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isAdmin = false;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthAndRoute();
  }

  Future<void> _checkAuthAndRoute() async {
    try {
      // ตรวจสอบ auth state
      final isLoggedIn = await AuthService.isLoggedIn();
      final isAdmin = await AuthService.isAdmin();
      final currentUser = await AuthService.getCurrentUser();

      setState(() {
        _isAuthenticated = isLoggedIn;
        _isAdmin = isAdmin;
        _currentUser = currentUser;
        _isLoading = false;
      });

      // อัปเดต auth state manager
      await AuthStateManager().refreshAuthState();
    } catch (e) {
      print('RouteHandler: Error checking auth: $e');
      setState(() {
        _isAuthenticated = false;
        _isAdmin = false;
        _currentUser = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    switch (widget.routeName) {
      case '/':
        // หากล็อกอินอยู่ ให้ส่งไปยังหน้าที่เหมาะสมตามบทบาททันทีเพื่อป้องกันการโผล่มาหน้าสาธารณะหลังรีเฟรช
        if (_isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isAdmin) {
              Navigator.of(context).pushNamedAndRemoveUntil('/admin-dashboard', (route) => false);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil('/user-home', (route) => false);
            }
          });
          return _buildRedirectingScreen('กำลังนำทางไปยังหน้าของคุณ...');
        }
        // ไม่ได้ล็อกอิน แสดงหน้า Homepage สาธารณะ
        return HomePage();
      
      case '/login':
        return LoginPage();
      
      case '/user-home':
        if (!_isAuthenticated) {
          // ถ้าไม่ได้ล็อกอิน แต่พยายามเข้าหน้า user-home ให้ไปหน้าหลัก
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          });
          return _buildRedirectingScreen('กำลังเปลี่ยนเส้นทาง...');
        }
        final userName = _currentUser != null 
            ? '${_currentUser!['firstName']} ${_currentUser!['lastName']}'
            : 'User';
        return UserHomePage(username: userName);
      
      case '/admin-dashboard':
        if (!_isAuthenticated || !_isAdmin) {
          // ถ้าไม่ได้ล็อกอินหรือไม่ใช่ admin ให้ไปหน้าหลัก
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          });
          return _buildRedirectingScreen('กำลังเปลี่ยนเส้นทาง...');
        }
        final adminName = _currentUser != null 
            ? '${_currentUser!['firstName']} ${_currentUser!['lastName']}'
            : 'Admin';
        return AdminDashboardPage(adminName: adminName);
      
      default:
        return HomePage();
    }
  }

  Widget _buildLoadingScreen() {
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

  Widget _buildRedirectingScreen(String message) {
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
              message,
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
}