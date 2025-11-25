import 'package:flutter/material.dart';
import 'SignUpPage.dart';
import 'UserHomePage.dart';
import 'EmailVerificationPage.dart';
import 'package:booking_web_full/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as html;
import 'ResetPasswordPage.dart';
import 'ForgotPasswordPage.dart';

class LoginPage extends StatefulWidget {
  final bool? verificationSuccess;
  final String? successMessage;
  
  const LoginPage({
    Key? key,
    this.verificationSuccess,
    this.successMessage,
  }) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerificationStatus();
    });
  }

  void _checkVerificationStatus() {
    try {
      // ตรวจสอบ URL parameters
      final url = html.window.location.href;
      final uri = Uri.parse(url);
      final hash = html.window.location.hash; // e.g., #/reset-password?token=...
      
    if (uri.queryParameters.containsKey('verified') && 
          uri.queryParameters['verified'] == 'true') {
        // แสดงข้อความยืนยันสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ยืนยันอีเมลสำเร็จ! คุณสามารถเข้าสู่ระบบได้แล้ว',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // ลบ query parameters จาก URL
        try {
          html.window.history.replaceState(null, '', '/login');
        } catch (e) {
          // Fallback for JSAny compatibility
          print('Could not update URL: $e');
        }
      }

      // If reset-password token exists in URL, open dedicated page
      if (uri.queryParameters['token'] != null && uri.path.contains('reset-password')) {
        final token = uri.queryParameters['token']!;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResetPasswordPage(token: token)),
        );
      } else if (hash.isNotEmpty && hash.contains('reset-password') && hash.contains('token=')) {
        // support SPA routers that put token in the hash
        final hashStr = hash.startsWith('#') ? hash.substring(1) : hash;
        final hashUri = Uri.parse(hashStr);
        final token = hashUri.queryParameters['token'];
        if (token != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ResetPasswordPage(token: token)),
          );
        }
      }
      
      // หรือแสดงข้อความจาก widget properties
      if (widget.verificationSuccess == true && widget.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text(widget.successMessage!)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // หากเกิดข้อผิดพลาดในการตรวจสอบ URL
      print('Error checking verification status: $e');
    }
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Normalize email to lowercase and trim whitespace
    final email = _emailController.text.toLowerCase().trim();
    final password = _passwordController.text;

    // แสดง loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // เรียก API สำหรับ login
      final result = await ApiService.login(
        email: email,
        password: password,
      );

      // ปิด loading dialog
      Navigator.pop(context);

      if (result['success']) {
        // บันทึกข้อมูลผู้ใช้
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', result['user']['id']);
        await prefs.setString('userEmail', result['user']['email']);
        await prefs.setString('userName', '${result['user']['firstName']} ${result['user']['lastName']}');

        // แสดงข้อความสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green),
        );

        // ตรวจสอบ role และนำทางไปหน้าที่เหมาะสม
        if (result['user']['role'] == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else {
          // User - ไปหน้า UserHomePage
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(
              builder: (_) => UserHomePage(
                username: '${result['user']['firstName']} ${result['user']['lastName']}',
              )
            )
          );
        }
      } else {
        // ตรวจสอบว่าเป็นกรณีที่อีเมลยังไม่ได้ยืนยันหรือไม่
        if (result.containsKey('emailNotVerified') && result['emailNotVerified'] == true) {
          // นำทางไปหน้ายืนยันอีเมล
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationPage(
                email: result['email'] ?? email,
                showResendOption: true,
              ),
            ),
          );
        } else {
          // แสดงข้อความผิดพลาด
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      // ปิด loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.teal[700]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'เข้าสู่ระบบ',
          style: TextStyle(color: Colors.teal[700]),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: isWideScreen ? 500 : double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    'SILPAKORN STADIUM',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ระบบจองสนามกีฬา มหาวิทยาลัยศิลปากร',
                    style: TextStyle(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  // Forgot password button moved to bottom; UI spacing here only
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person),
                      labelText: 'อีเมล / ชื่อผู้ใช้',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'กรุณากรอกอีเมล' : null,
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    textInputAction:
                        TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (_formKey.currentState!.validate()) {
                        _handleLogin();
                      }
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock),
                      labelText: 'รหัสผ่าน',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'กรุณากรอกรหัสผ่าน' : null,
                  ),
                  
                  SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _handleLogin();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'เข้าสู่ระบบ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                  onPressed: () {
                  Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SignUpPage()), // ไปที่หน้า SignUpPage
                  );
                  },
                    child: Text('ลงทะเบียน',
                    style: TextStyle(color: Colors.teal[700])),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                      );
                    },
                    child: const Text('ลืมรหัสผ่าน?', style: TextStyle(color: Colors.teal)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

// ResetPasswordPage moved to separate file
